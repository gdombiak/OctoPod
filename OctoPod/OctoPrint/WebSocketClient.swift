import Foundation
import Starscream

class WebSocketClient : NSObject, WebSocketDelegate {
    var serverURL: String!
    var apiKey: String!
    var username: String?
    var password: String?
    
    var socket: WebSocket?
    var socketRequest: URLRequest?
    
    // Keep track if we have an opened websocket connection
    var active: Bool = false
    var connecting: Bool = false
    var openRetries: Int = -1;
    var closedByUser: Bool = false

    var heartbeatTimer : Timer?
    
    var delegate: WebSocketClientDelegate?

    init(printer: Printer) {
        super.init()
        serverURL = printer.hostname
        apiKey = printer.apiKey
        username = printer.username
        password = printer.password
        
        let urlString: String = "\(serverURL!)/sockjs/websocket"
        
        self.socketRequest = URLRequest(url: URL(string: urlString)!)
        self.socketRequest!.timeoutInterval = 5
        if username != nil && password != nil {
            // Add authorization header
            let plainData = (username! + ":" + password!).data(using: String.Encoding.utf8)
            let base64String = plainData!.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
            self.socketRequest!.setValue("Basic " + base64String, forHTTPHeaderField: "Authorization")
        }
        self.socket = WebSocket(request: self.socketRequest!)
        
        // Add as delegate of Websocket
        socket!.delegate = self
        // Establish websocket connection
        self.establishConnection()
    }

    // MARK: - WebSocketDelegate

    func websocketDidConnect(socket: Starscream.WebSocketClient) {
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
    
    func websocketDidDisconnect(socket: Starscream.WebSocketClient, error: Error?) {
        active = false
        connecting = false
        // Stop heatbeat timer
        heartbeatTimer?.invalidate()
        
        if let _ = error {
            // Retry up to 5 times to open a websocket connection
            if !closedByUser {
                if openRetries < 6 {
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
    
    func websocketDidReceiveMessage(socket: Starscream.WebSocketClient, text: String) {
        if let listener = delegate {
            do {
                if let json = try JSONSerialization.jsonObject(with: text.data(using: String.Encoding.utf8)!, options: [.mutableLeaves, .mutableContainers]) as? NSDictionary {
                    if let current = json["current"] as? NSDictionary {
//                        NSLog("Websocket current state received: \(json)")
                        let event = CurrentStateEvent()
                        
                        if let state = (current["state"] as? NSDictionary) {
                            event.parseState(state: state)
                        }
                        
                        if let temps = current["temps"] as? NSArray {
                            if temps.count > 0 {
                                if let tempFirst = temps[0] as? NSDictionary {
                                    event.parseTemps(temp: tempFirst)
                                }
                            }
                        }
                        
                        event.currentZ = current["currentZ"] as? Double
                        
                        if let progress = current["progress"] as? NSDictionary {
                            event.parseProgress(progress: progress)
                        }
                        
                        listener.currentStateUpdated(event: event)
                    } else {
//                        NSLog("Websocket message received: \(text)")
                    }
                }
            } catch {
                NSLog("Error parsing websocket new accessory into NSDictionary: " + text)
            }
        }
    }
    
    func websocketDidReceiveData(socket: Starscream.WebSocketClient, data: Data) {
        // Do nothing
        NSLog("Websocket received data - \(self.hash)")
    }
    
    // MARK: - Private functions

    func establishConnection() {
        if connecting {
            // Nothing to do
            return
        }
        connecting = true
        // Increment number of times we are trying to establish a websockets connection
        openRetries = openRetries + 1
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
        socket?.disconnect()
    }
    
    // Return true if websocket is connected to the URL of the specified printer
    func isConnected(printer: Printer) -> Bool {
        if let currentSocket = socket {
            return currentSocket.isConnected && serverURL == printer.hostname
        }
        return false
    }
    
    fileprivate func socketWrite(text: String) {
        if active {
            socket?.write(string: text)
        }
    }
    
    fileprivate func recreateSocket() {
        // Remove self as a delegate from old socket
        socket!.delegate = nil
        
        self.socket = WebSocket(request: self.socketRequest!)
        
        // Add as delegate of Websocket
        socket!.delegate = self
    }
    
    @objc func sendHeartbeat() {
        socketWrite(text: " ")
    }
}
