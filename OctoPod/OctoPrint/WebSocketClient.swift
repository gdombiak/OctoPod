import Foundation
import Starscream

// Classic websocket client that connects to "<octoprint>/sockjs/websocket"
// To receive socket events and received messages, create a WebSocketClientDelegate
// and add it as a delegate of this WebSocketClient
class WebSocketClient: NSObject, WebSocketAdvancedDelegate {

    private static let socketQueueKey = DispatchSpecificKey<Void>()

    /// Serial owner of connect / write / heartbeat / disconnect / recreate.
    /// Starscream callbacks are delivered here so those mutations cannot overlap.
    private let socketQueue = DispatchQueue(label: "org.OctoPod.WebSocketClient")

    private let appConfiguration: AppConfiguration
    private let printerURL: String
    private let serverURL: String

    var sharedNozzle: Bool
    var delegate: WebSocketClientDelegate?

    private var socket: WebSocket?
    private var socketRequest: URLRequest
    /// Bumped on every teardown so a delayed retry cannot connect a replaced socket.
    private var connectGeneration = 0

    private var active = false
    private var connecting = false
    private var openRetries = -1
    private var parseFailures = 0
    private var connectionAborted = false
    private var closedByUser = false

    private var heartbeatTimer: DispatchSourceTimer?

    init(appConfiguration: AppConfiguration, printerURL: String, hostname: String, apiKey _: String, username: String?, password: String?, headers: String?, sharedNozzle: Bool) {
        self.appConfiguration = appConfiguration
        self.printerURL = printerURL
        var hostname = hostname
        hostname = hostname.hasSuffix("/") ? String(hostname.dropLast()) : hostname
        self.serverURL = hostname
        self.sharedNozzle = sharedNozzle

        let urlString = "\(hostname)/sockjs/websocket"
        let socketURL = URL(string: urlString)!
        var request = URLRequest(url: socketURL)
        request.timeoutInterval = 5
        if let username = username, let password = password, !username.isEmpty, !password.isEmpty {
            let plainData = (username + ":" + password).data(using: String.Encoding.utf8)
            let base64String = plainData!.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
            request.setValue("Basic " + base64String, forHTTPHeaderField: "Authorization")
        }
        if let headers = URLUtils.parseHeaders(headers: headers) {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        if let host = socketURL.host {
            if let port = socketURL.port {
                request.setValue("\(host):\(port)", forHTTPHeaderField: "Host")
            } else {
                request.setValue(host, forHTTPHeaderField: "Host")
            }
        }
        self.socketRequest = request
        super.init()
        socketQueue.setSpecific(key: WebSocketClient.socketQueueKey, value: ())
        onSocketQueue {
            self.createWebSocket()
            self.establishConnection()
        }
    }

    deinit {
        heartbeatTimer?.cancel()
        heartbeatTimer = nil
        if let socket = socket {
            socket.advancedDelegate = nil
            if socket.isConnected {
                socket.disconnect(forceTimeout: 0, closeCode: CloseCode.normal.rawValue)
            }
        }
    }

    // MARK: - Authentication

    /// OctoPrint 1.3.10 now requires websockets to authenticate in order to become active. This is
    /// the default behavior now even though users can disable this. The session is obtained from
    /// doing a passive login
    func authenticate(user: String, session: String) {
        onSocketQueue {
            self.socketWrite(text: "{\"auth\": \"\(user):\(session)\"}")
        }
    }

    // MARK: - WebSocketAdvancedDelegate

    func websocketDidConnect(socket: WebSocket) {
        guard self.socket === socket else { return }

        active = true
        connecting = false
        openRetries = 0
        closedByUser = false
        startHeartbeat()

        NSLog("Websocket CONNECTED - \(self.hash)")
        notify { $0.websocketConnected() }
    }

    func websocketDidDisconnect(socket: WebSocket, error: Error?) {
        guard self.socket === socket else { return }

        active = false
        connecting = false
        stopHeartbeat()

        if connectionAborted {
            return
        }

        if let error = error {
            if !closedByUser {
                if openRetries < 6 {
                    if let wsError = error as? WSError, wsError.type == ErrorType.upgradeError {
                        // Remove Host header in case we are running into a CORS issue. This is a hack so that users do not need to
                        // enable CORS on the server when running behind a reverse proxy. This is how it used to run before version 2.2
                        socketRequest.setValue(nil, forHTTPHeaderField: "Host")
                    }
                    replaceSocket()
                    establishConnection()
                } else {
                    if let wsError = error as? WSError {
                        NSLog("Websocket disconnected. Error: \(wsError.message) (\(wsError.code)) - \(self.hash)")
                    } else {
                        NSLog("Websocket disconnected. Error: \(String(describing: error.localizedDescription)) - \(self.hash)")
                    }
                    notify { $0.websocketConnectionFailed(error: error) }
                }
            } else {
                NSLog("Websocket disconnected - \(self.hash)")
            }
        }
    }

    func websocketDidReceiveMessage(socket: WebSocket, text: String, response: WebSocket.WSResponse) {
        if self.socket !== socket {
            // Ignore messages coming from a different websocket.
            // This could happen when user switched between printers and the thread
            // that reads from old websocket is still processing incoming data
            // Or it could happpen if a new websocket was created to the existing OctoPrint
            NSLog("Ignoring message from old websocket: \(text)")
            return
        }
        guard delegate != nil else { return }
        do {
            if let json = try JSONSerialization.jsonObject(with: text.data(using: String.Encoding.utf8)!, options: [.mutableLeaves, .mutableContainers]) as? NSDictionary {
                parseFailures = 0
                handleJSONMessage(json)
            }
        } catch {
            if !socket.isConnected {
                NSLog("JSON parsed error and websocket is already disconnected")
            } else {
                NSLog("Error parsing websocket message: \(text)")
                parseFailures = parseFailures + 1
                if parseFailures > 6 {
                    NSLog("Giving up recreating websocket. Last parsing error: \(error)")
                    abortConnection(error: error)
                    return
                }
                NSLog("Recreating websocket due to parsing error: \(error)")
                replaceSocket()
                establishConnection()
            }
        }
    }

    func websocketDidReceiveData(socket: WebSocket, data: Data, response: WebSocket.WSResponse) {
        NSLog("Websocket received data - \(self.hash)")
    }

    func websocketHttpUpgrade(socket: WebSocket, request: String) {
    }

    func websocketHttpUpgrade(socket: WebSocket, response: String) {
    }

    // MARK: - Public lifecycle

    func closeConnection() {
        onSocketQueueSync {
            self.openRetries = -1
            self.closedByUser = true
            self.stopCurrentSocket()
        }
    }

    /// Return true if websocket is connected to the URL of the specified printer
    func isConnected(hostname: String) -> Bool {
        onSocketQueueSync {
            self.active && self.serverURL == hostname
        }
    }

    // MARK: - Private functions

    private func establishConnection() {
        if connecting {
            return
        }
        if socketRequest.url?.scheme == nil {
            NSLog("socketRequest has no url or url has no schema. URL: \(socketRequest.url?.absoluteString ?? "no url")")
            let error = NSError(domain: "NSPOSIXErrorDomain", code: 61, userInfo: nil)
            notify { $0.websocketConnectionFailed(error: error) }
            return
        }
        connectionAborted = false
        connecting = true
        openRetries = openRetries + 1
        let generation = connectGeneration
        if openRetries > 0 {
            NSLog("Retrying websocket connection after \(openRetries * 300) milliseconds")
            socketQueue.asyncAfter(deadline: .now() + .milliseconds(openRetries * 300)) { [weak self] in
                guard let self = self else { return }
                guard self.connectGeneration == generation, self.connecting, !self.closedByUser else { return }
                self.socket?.connect()
            }
        } else {
            socket?.connect()
        }
    }

    private func abortConnection(error: Error) {
        openRetries = -1
        closedByUser = false
        connectionAborted = true
        stopCurrentSocket()
        createWebSocket()

        NSLog("Websocket corrupted?. Error: \(String(describing: error.localizedDescription)) - \(self.hash)")
        notify { $0.websocketConnectionFailed(error: error) }
    }

    private func createWebSocket() {
        let socket = WebSocket(request: socketRequest)
        socket.disableSSLCertValidation = appConfiguration.certValidationDisabled()
        socket.callbackQueue = socketQueue
        socket.advancedDelegate = self
        self.socket = socket
    }

    private func socketWrite(text: String) {
        guard active else { return }
        socket?.write(string: text)
    }

    /// Drop the current Starscream socket without accepting further writes.
    ///
    /// Starscream 3.1.1 `disconnect(forceTimeout: 0)` hits `disconnectStream(nil)`,
    /// which calls `writeQueue.waitUntilAllOperationsAreFinished()` *before*
    /// `cleanupStream()`. That is what makes it safe to release the socket
    /// immediately afterward. `callbackQueue` only affects delegate delivery;
    /// the wait is what serializes Starscream's internal write `OperationQueue`
    /// against stream teardown. `guard isConnected` means a still-handshaking
    /// socket skips that path and is released via deinit instead.
    private func stopCurrentSocket() {
        connectGeneration += 1
        active = false
        connecting = false
        stopHeartbeat()
        guard let socket = socket else { return }
        socket.advancedDelegate = nil
        if socket.isConnected {
            socket.disconnect(forceTimeout: 0, closeCode: CloseCode.normal.rawValue)
        }
        self.socket = nil
    }

    private func replaceSocket() {
        stopCurrentSocket()
        createWebSocket()
    }

    private func startHeartbeat() {
        stopHeartbeat()
        let timer = DispatchSource.makeTimerSource(queue: socketQueue)
        timer.schedule(deadline: .now(), repeating: 40)
        timer.setEventHandler { [weak self] in
            self?.socketWrite(text: "{}")
        }
        timer.resume()
        heartbeatTimer = timer
    }

    private func stopHeartbeat() {
        heartbeatTimer?.cancel()
        heartbeatTimer = nil
    }

    private func onSocketQueue(_ work: @escaping () -> Void) {
        if DispatchQueue.getSpecific(key: WebSocketClient.socketQueueKey) != nil {
            work()
        } else {
            socketQueue.async(execute: work)
        }
    }

    @discardableResult
    private func onSocketQueueSync<T>(_ work: () -> T) -> T {
        if DispatchQueue.getSpecific(key: WebSocketClient.socketQueueKey) != nil {
            return work()
        }
        return socketQueue.sync(execute: work)
    }

    private func notify(_ body: @escaping (WebSocketClientDelegate) -> Void) {
        guard let delegate = delegate else { return }
        DispatchQueue.main.async {
            body(delegate)
        }
    }

    private func handleJSONMessage(_ json: NSDictionary) {
        if let current = json["current"] as? NSDictionary {
            let event = CurrentStateEvent(printerURL: printerURL)

            if let state = (current["state"] as? NSDictionary) {
                event.parseState(state: state)
            }

            if let job = (current["job"] as? NSDictionary) {
                event.parseJob(job: job)
            }

            if let temps = current["temps"] as? NSArray {
                if temps.count > 0 {
                    if let tempFirst = temps[0] as? NSDictionary {
                        event.parseTemps(temp: tempFirst, sharedNozzle: sharedNozzle)
                    }
                }
            }

            event.currentZ = current["currentZ"] as? Double

            if let progress = current["progress"] as? NSDictionary {
                event.parseProgress(progress: progress)
            }

            if let logs = current["logs"] as? NSArray {
                event.parseLogs(logs: logs)
            }

            notify { $0.currentStateUpdated(event: event) }
        } else if let event = json["event"] as? NSDictionary {
            if let type = event["type"] as? String {
                if type == "SettingsUpdated" {
                    notify { $0.octoPrintSettingsUpdated() }
                } else if type == "PrinterProfileModified" {
                    notify { $0.printerProfileUpdated() }
                } else if type == "TransferDone" || type == "TransferFailed" {
                    let event = CurrentStateEvent(printerURL: printerURL)
                    event.printing = false
                    event.progressCompletion = 100
                    event.progressPrintTimeLeft = 0
                    notify { $0.currentStateUpdated(event: event) }
                } else if type == "PrinterStateChanged" {
                    if let payload = event["payload"] as? NSDictionary {
                        if let state_id = payload["state_id"] as? String, let state_string = payload["state_string"] as? String {
                            var event: CurrentStateEvent?
                            if state_id == "PRINTING" {
                                event = CurrentStateEvent(printerURL: printerURL)
                                event!.printing = true
                                event!.state = state_string
                            } else if state_id == "OPERATIONAL" {
                                event = CurrentStateEvent(printerURL: printerURL)
                                event!.printing = false
                                event!.state = state_string
                            }
                            if let event = event {
                                notify { $0.currentStateUpdated(event: event) }
                            }
                        }
                    }
                } else if type == "PrintDone" {
                    let event = CurrentStateEvent(printerURL: printerURL)
                    event.printing = false
                    event.progressCompletion = 100
                    event.progressPrintTimeLeft = 0
                    notify { $0.currentStateUpdated(event: event) }
                } else if type == "PrintCancelled" {
                    let event = CurrentStateEvent(printerURL: printerURL)
                    event.printing = false
                    event.progressCompletion = 0
                    event.progressPrintTime = 0
                    event.progressPrintTimeLeft = 0
                    notify { $0.currentStateUpdated(event: event) }
                }
            }
        } else if let history = json["history"] as? NSDictionary {
            if let temps = history["temps"] as? NSArray {
                var historyTemps = Array<TempHistory.Temp>()
                for case let temp as NSDictionary in temps {
                    var historyTemp = TempHistory.Temp()
                    historyTemp.parseTemps(temp: temp, sharedNozzle: sharedNozzle)
                    historyTemps.append(historyTemp)
                }
                notify { $0.historyTemp(history: historyTemps) }
            }
        } else if let plugin = json["plugin"] as? NSDictionary {
            if let identifier = plugin["plugin"] as? String, let data = plugin["data"] as? NSDictionary {
                notify { $0.pluginMessage(plugin: identifier, data: data) }
            }
        }
    }
}
