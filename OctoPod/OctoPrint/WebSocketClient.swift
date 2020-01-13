import Foundation
import Starscream

// Classic websocket client that connects to "<octoprint>/sockjs/websocket"
// To receive socket events and received messages, create a WebSocketClientDelegate
// and add it as a delegate of this WebSocketClient
class WebSocketClient : NSObject, WebSocketAdvancedDelegate {
    
    /// Create a serial queue for thread-safety when closing sockets. Serial is ok
    /// since we do not have concurrent read threads
    static private let closingQueue = DispatchQueue(label: "WebSocketClosingQueue")
    /// Array of web sockets that are being closed. We keep them in a collection
    /// since closing a websocket involves the client requesting the server to
    /// close the socket. This means that the socket is still operational so we cannot release its reference
    /// from memory. Releasing the reference will end up with a read-thread operating on a no-longer existing
    /// object and the app will crash if this happens. See [bug](https://github.com/gdombiak/OctoPod/issues/217)
    static private var closingSockets: Dictionary<WebSocket, Date> = Dictionary()
    static private let SOCKET_CLOSING_EXPIRATION = 10 // time in seconds to keep socket in memory
    static private var cleanupTimer: Timer?

    var serverURL: String!
    var apiKey: String!
    var username: String?
    var password: String?
    var sharedNozzle: Bool!
    
    var socket: WebSocket?
    var socketRequest: URLRequest?
    
    // Keep track if we have an opened websocket connection
    var active: Bool = false
    var connecting: Bool = false
    var openRetries: Int = -1;
    var parseFailures: Int = 0  // Number of consecutive parse errors
    var connectionAborted: Bool = false // Connection is aborted when we had too many consecutive parse errors even after recreating the websocket
    var closedByUser: Bool = false

    var heartbeatTimer : Timer?
    
    var delegate: WebSocketClientDelegate?

    init(printer: Printer) {
        super.init()
        serverURL = printer.hostname
        apiKey = printer.apiKey
        username = printer.username
        password = printer.password
        sharedNozzle = printer.sharedNozzle
        
        let urlString: String = "\(serverURL!)/sockjs/websocket"
        
        let socketURL = URL(string: urlString)!
        self.socketRequest = URLRequest(url: socketURL)
        self.socketRequest!.timeoutInterval = 5
        if username != nil && password != nil {
            // Add authorization header
            let plainData = (username! + ":" + password!).data(using: String.Encoding.utf8)
            let base64String = plainData!.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
            self.socketRequest!.setValue("Basic " + base64String, forHTTPHeaderField: "Authorization")
        }
        // Set Host header to prevent CORS issues
        if let host = socketURL.host {
            if let port = socketURL.port {
                self.socketRequest!.setValue("\(host):\(port)", forHTTPHeaderField: "Host")
            } else {
                self.socketRequest!.setValue(host, forHTTPHeaderField: "Host")
            }
        }
        createWebSocket()
        
        // Add as delegate of Websocket
        socket!.advancedDelegate = self
        // Establish websocket connection
        self.establishConnection()
    }

    // MARK: - Authentication
    
    /// OctoPrint 1.3.10 now requires websockets to authenticate in order to become active. This is
    /// the default behavior now even though users can disable this. The session is obtained from
    /// doing a passive login
    func authenticate(user: String, session: String) {
        socketWrite(text: "{\"auth\": \"\(user):\(session)\"}")
    }

    // MARK: - WebSocketAdvancedDelegate
    
    func websocketDidConnect(socket: WebSocket) {
        active = true
        connecting = false
        openRetries = 0
        closedByUser = false
        
        heartbeatTimer = Timer.scheduledTimer(timeInterval: 40, target: self, selector: #selector(sendHeartbeat), userInfo: nil, repeats: true)
        heartbeatTimer?.fire()
        
        NSLog("Websocket CONNECTED - \(self.hash)")
        if let listener = delegate {
            listener.websocketConnected()
        }
    }
    
    func websocketDidDisconnect(socket: WebSocket, error: Error?) {
        // We can now release any reference to the socket that got closed
        WebSocketClient.closingQueue.async {
            WebSocketClient.forgetSocket(socket: socket)
        }

        active = false
        connecting = false
        // Stop heatbeat timer
        heartbeatTimer?.invalidate()
        
        if connectionAborted {
            // Nothing to do since we decided to abort connecting
            return
        }
        
        if let _ = error {
            // Retry up to 5 times to open a websocket connection
            if !closedByUser {
                if openRetries < 6 {
                    if let wsError = error as? WSError, wsError.type == ErrorType.upgradeError {
                        // Remove Host header in case we are running into a CORS issue. This is a hack so that users do not need to
                        // enable CORS on the server when running behind a reverse proxy. This is how it used to run before version 2.2
                        self.socketRequest!.setValue(nil, forHTTPHeaderField: "Host")
                    }
                    recreateSocket()
                    establishConnection()
                } else {
                    NSLog("Websocket disconnected. Error: \(String(describing: error?.localizedDescription)) - \(self.hash)")
                    if let listener = delegate {
                        listener.websocketConnectionFailed(error: error!)
                    }
                }
            } else {
                NSLog("Websocket disconnected - \(self.hash)")
            }
        }
    }
    
    func websocketDidReceiveMessage(socket: WebSocket, text: String, response: WebSocket.WSResponse) {
        if self.socket != socket {
            // Ignore messages coming from a different websocket.
            // This could happen when user switched between printers and the thread
            // that reads from old websocket is still processing incoming data
            // Or it could happpen if a new websocket was created to the existing OctoPrint
            NSLog("Ignoring message from old websocket: \(text)")
            return
        }
        if let listener = delegate {
            do {
                if let json = try JSONSerialization.jsonObject(with: text.data(using: String.Encoding.utf8)!, options: [.mutableLeaves, .mutableContainers]) as? NSDictionary {
                    // Reset counter of consecutive parse failures
                    parseFailures = 0
                    if let current = json["current"] as? NSDictionary {
//                        NSLog("Websocket current state received: \(json)")
                        let event = CurrentStateEvent()
                        
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

                        listener.currentStateUpdated(event: event)
                    } else if let event = json["event"] as? NSDictionary {
                        // Check if settings were updated
                        if let type = event["type"] as? String {
                            if type == "SettingsUpdated" {
                                listener.octoPrintSettingsUpdated()
                            } else if type == "PrinterProfileModified" {
                                listener.printerProfileUpdated()
                            } else if type == "TransferDone" || type == "TransferFailed" {
                                // Events denoting that upload to SD card is done or was cancelled
                                let event = CurrentStateEvent()
                                event.printing = false
                                event.progressCompletion = 100
                                event.progressPrintTimeLeft = 0
                                // Notify listener
                                listener.currentStateUpdated(event: event)
                            } else if type == "PrinterStateChanged" {
                                if let payload =  event["payload"] as? NSDictionary {
                                    if let state_id = payload["state_id"] as? String, let state_string = payload["state_string"] as? String {
                                        var event: CurrentStateEvent?
                                        if state_id == "PRINTING" {
                                            // Event indicating that printer is busy. Could be printing or uploading file to SD Card
                                            event = CurrentStateEvent()
                                            event!.printing = true
                                            event!.state = state_string
                                        } else if state_id == "OPERATIONAL" {
                                            // Event indicating that printer is ready to be used
                                            event = CurrentStateEvent()
                                            event!.printing = false
                                            event!.state = state_string
                                        }
                                        if let _ = event {
                                            // Notify listener
                                            listener.currentStateUpdated(event: event!)
                                        }
                                    }
                                }
                            } else if type == "PrintDone" {
                                // Event denoting that print is done
                                let event = CurrentStateEvent()
                                event.printing = false
                                event.progressCompletion = 100
                                event.progressPrintTimeLeft = 0
                                // Notify listener
                                listener.currentStateUpdated(event: event)
                            } else if type == "PrintCancelled" {
                                // Event denoting that print has been cancelled
                                let event = CurrentStateEvent()
                                event.printing = false
                                event.progressCompletion = 0
                                event.progressPrintTime = 0
                                event.progressPrintTimeLeft = 0
                                // Notify listener
                                listener.currentStateUpdated(event: event)
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
                            // Notify listener
                            listener.historyTemp(history: historyTemps)
                        }
                    } else if let plugin = json["plugin"] as? NSDictionary {
                        if let identifier = plugin["plugin"] as? String, let data = plugin["data"] as? NSDictionary {
                            // Notify listener
                            listener.pluginMessage(plugin: identifier, data: data)
                        }
                    } else {
//                        NSLog("Websocket message received: \(text)")
                    }
                }
            } catch {
                if !socket.isConnected {
                    // Websocket is no longer connected and received JSON was invalid so was not possible to parse it
                    // Just log this. #websocketDidDisconnect will be called after this
                    NSLog("JSON parsed error and websocket is already disconnected") // We are consuming from in-memory queue
                } else {
                    NSLog("Error parsing websocket message: \(text)")
                    // Increment number of times we are trying to recover websocket from consecutive parse errors
                    parseFailures = parseFailures + 1
                    if parseFailures > 6 {
                        NSLog("Giving up recreating websocket. Last parsing error: \(error)" )
                        // Websocket was recreated 6 times and each time we had a parse error when parsing the
                        // first message. OctoPrint is having big issues so we cannot recover at this point
                        // Close the connection and alert we are no longer connected / refreshing
                        abortConnection(error: error)
                        return
                    }
                    NSLog("Recreating websocket due to parsing error: \(error)" )
                    disconnectSocket(socket: socket) // Close connection so we stop receiving messages
                    // Attempt to recreate socket
                    recreateSocket()
                    establishConnection()
                }
            }
        }
    }
    
    func websocketDidReceiveData(socket: WebSocket, data: Data, response: WebSocket.WSResponse) {
        // Do nothing. This is for Binary frames
        NSLog("Websocket received data - \(self.hash)")
    }
    
    func websocketHttpUpgrade(socket: WebSocket, request: String) {
        // Do nothing
    }

    func websocketHttpUpgrade(socket: WebSocket, response: String) {
        // Do nothing
    }

    // MARK: - Private functions

    fileprivate func establishConnection() {
        if connecting {
            // Nothing to do
            return
        }
        connectionAborted = false
        connecting = true
        // Increment number of times we are trying to establish a websockets connection
        openRetries = openRetries + 1
//        socket?.onText = { text in
//            print("\(self.socket!) - \(text)")
//        }
        if openRetries > 0 {
            NSLog("Retrying websocket connection after \(openRetries * 300) milliseconds")
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(openRetries * 300), execute: {
                // Try establishing the connection
                self.socket?.connect()
            })
        } else {
            // Try establishing the connection
            socket?.connect()
        }
    }
    
    func closeConnection() {
        openRetries = -1
        closedByUser = true
        if let socket = socket, socket.isConnected {
            disconnectSocket(socket: socket)
        }
        socket = nil
    }
    
    fileprivate func disconnectSocket(socket: WebSocket) {
        // Remember socket before releasing reference to it. Add an expiration
        // date for how long to remember. A background thread removes
        // expired sockets. We have to do this since asking Websocket to disconnect
        // just sends a request to the server and the server needs to close the connection
        // and there is a chance that the server will send more data before closing the
        // connection and the data that is read will produce a crash of the app since
        // the read thread of StarScream will operate on an object that is gone from memory
        WebSocketClient.closingQueue.async {
            // Remember socket that is being closed
            WebSocketClient.rememberSocket(socket: socket)
        }
        socket.disconnect()
    }
    
    fileprivate func abortConnection(error: Error) {
        openRetries = -1
        closedByUser = false
        connectionAborted = true // Indicate that we decided to abort connecting
        if let socket = socket, socket.isConnected {
            disconnectSocket(socket: socket)
        }

        recreateSocket() // Recreate websocket object (not the actual network connection). In-memory queue of read messages will be ignored

        NSLog("Websocket corrupted?. Error: \(String(describing: error.localizedDescription)) - \(self.hash)")
        if let listener = delegate {
            listener.websocketConnectionFailed(error: error)
        }
    }
    
    // Return true if websocket is connected to the URL of the specified printer
    func isConnected(printer: Printer) -> Bool {
        if let currentSocket = socket {
            return currentSocket.isConnected && serverURL == printer.hostname
        }
        return false
    }
    
    fileprivate func createWebSocket() {
        self.socket = WebSocket(request: self.socketRequest!)
        // Configure if SSL certificate validation is disabled or not
        DispatchQueue.main.async {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            self.socket?.disableSSLCertValidation = appDelegate.appConfiguration.certValidationDisabled()
        }
    }
    
    fileprivate func socketWrite(text: String) {
        if active {
            socket?.write(string: text)
        }
    }
    
    fileprivate func recreateSocket() {
        // Remove self as a delegate from old socket
        socket!.advancedDelegate = nil
        
        createWebSocket()
        
        // Add as delegate of Websocket
        socket!.advancedDelegate = self
    }
    
    @objc func sendHeartbeat() {
        socketWrite(text: "{}")
    }
    
    // MARK: - Static closing sockets functions

    @objc static func cleanupClosingSockets() {
        // Clean up expired sockets that we asked to close and the server never closed them
        closingQueue.async {
            for toRemove in closingSockets.filter({ (key: WebSocket, value: Date) -> Bool in
                return value < Date()
            }) {
                if toRemove.key.isConnected {
                    // This time we force a disconnect from streams. This will stop read/write threads
                    // rather than asking the server to close the connection
                    toRemove.key.disconnect(forceTimeout: 0, closeCode: CloseCode.normal.rawValue)
                }
                forgetSocket(socket: toRemove.key)
            }
        }
    }
    
    fileprivate static func rememberSocket(socket: WebSocket) {
        if closingSockets.isEmpty {
            // Start background thread that removes expired sockets
            // Timer needs to be started from main thread to be repeatable
            DispatchQueue.main.async {
                cleanupTimer = Timer.scheduledTimer(timeInterval: TimeInterval(SOCKET_CLOSING_EXPIRATION), target: self, selector: #selector(cleanupClosingSockets), userInfo: nil, repeats: true)
                cleanupTimer?.fire()
            }
        }

        closingSockets[socket] = Date().addingTimeInterval(TimeInterval(SOCKET_CLOSING_EXPIRATION))
    }
    
    fileprivate static func forgetSocket(socket: WebSocket) {
        closingSockets.removeValue(forKey: socket)
        // Stop background thread if there are no more sockets to verify their expiration
        if closingSockets.isEmpty {
            cleanupTimer?.invalidate()
        }
    }
}
