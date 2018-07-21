import Foundation

// OctoPrint client that exposes the REST API described
// here: http://docs.octoprint.org/en/master/api/index.html
// A OctoPrintClient can connect to a single OctoPrint server at a time
//
// OctoPrintClient uses websockets for getting realtime updates from OctoPrint (read operations only)
// and an HTTP Client is used for requesting services on the OctoPrint server.
class OctoPrintClient: WebSocketClientDelegate {
    
    enum axis {
        case X
        case Y
        case Z
        case E
    }
    
    var httpClient: HTTPClient?
    var webSocketClient: WebSocketClient?
    
    let terminal = Terminal()
    
    var delegates: Array<OctoPrintClientDelegate> = Array()
    
    // MARK: - OctoPrint server connection
    
    // Connect to OctoPrint server and gather printer state
    // A websocket connection will be attempted to get real time updates from OctoPrint
    // An HTTPClient is created for sending requests to OctoPrint
    func connectToServer(printer: Printer) {
        // Create and keep httpClient while default printer does not change
        httpClient = HTTPClient(printer: printer)
        
        if webSocketClient?.isConnected(printer: printer) == true {
            // Do nothing since we are already connected to the default printer
            return
        }
        
        for delegate in delegates {
            delegate.notificationAboutToConnectToServer()
        }
        // Close any previous connection
        webSocketClient?.closeConnection()
        
        // Create websocket connection and connect
        webSocketClient = WebSocketClient(printer: printer)
        // Subscribe to events so we can update the UI as events get pushed
        webSocketClient?.delegate = self

        // It might take some time for Octoprint to report current state via websockets so ask info via HTTP
        printerState { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
            if !self.isConnectionError(error: error, response: response) {
                // There were no errors so process
                var event: CurrentStateEvent?
                if let json = result as? NSDictionary {
                    event = CurrentStateEvent()
                    if let temp = json["temperature"] as? NSDictionary {
                        event!.parseTemps(temp: temp)
                    }
                    if let state = json["state"] as? NSDictionary {
                        event!.parseState(state: state)
                    }
                } else if response.statusCode == 409 {
                    // Printer is not operational
                    event = CurrentStateEvent()
                    event!.closedOrError = true
                    event!.state = "Offline"
                }
                if let _ = event {
                    // Notify that we received new status information from OctoPrint
                    self.currentStateUpdated(event: event!)
                }
            } else {
                // Notify of connection error
                for delegate in self.delegates {
                    delegate.handleConnectionError(error: error, response: response)
                }
            }
        }
    }
    
    // Disconnect from OctoPrint server
    func disconnectFromServer() {
        httpClient = nil
        webSocketClient?.closeConnection()
        webSocketClient = nil
    }
    
    fileprivate func isConnectionError(error: Error?, response: HTTPURLResponse) -> Bool {
        if let _ = error as NSError? {
            return true
        } else if response.statusCode == 403 {
            return true
        } else {
            // Return that there were no errors
            return false
        }
    }

    // MARK: - WebSocketClientDelegate
    
    // Notification that OctoPrint state has changed. This may include printer status information
    func currentStateUpdated(event: CurrentStateEvent) {
        // Notify the terminal that OctoPrint and/or Printer state has changed
        terminal.currentStateUpdated(event: event)
        // Notify other listeners that OctoPrint and/or Printer state has changed
        for delegate in delegates {
            delegate.printerStateUpdated(event: event)
        }
    }
    
    // Notification sent when websockets got connected
    func websocketConnected() {
        // Notify the terminal that we connected to OctoPrint
        terminal.websocketConnected()
        // Notify other listeners that we connected to OctoPrint
        for delegate in delegates {
            delegate.websocketConnected()
        }
    }
    
    // Notification sent when websockets got disconnected due to an error (or failed to connect)
    func websocketConnectionFailed(error: Error) {
        for delegate in delegates {
            delegate.websocketConnectionFailed(error: error)
        }
    }

    // MARK: - Connection operations

    // Return connection status from OctoPrint to the 3D printer
    func connectionPrinterStatus(callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            client.get("/api/connection") { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                // Check if there was an error
                if let _ = error {
                    NSLog("Error getting connection status. Error: \(error!.localizedDescription)")
                }
                callback(result, error, response)
            }
        }
    }
    
    // Ask OctoPrint to connect using default settings. We always get 204 status code (unless there was some network error)
    // To know if OctoPrint was able to connect to the 3D printer then we need to check for its connection status
    func connectToPrinter(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "connect"

            connectionPost(httpClient: client, json: json, callback: callback)
        }
    }

    // Ask OctoPrint to disconnect from the 3D printer. Use connection status to check if it was successful
    func disconnectFromPrinter(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "disconnect"
            
            connectionPost(httpClient: client, json: json, callback: callback)
        }
    }
    
    // MARK: - Job operations

    func currentJobInfo(callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            client.get("/api/job") { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                // Check if there was an error
                if let _ = error {
                    NSLog("Error getting printer state. Error: \(error!.localizedDescription)")
                }
                callback(result, error, response)
            }
        }
    }
    
    func pauseCurrentJob(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "pause"
            json["action"] = "pause"

            jobPost(httpClient: client, json: json, callback: callback)
        }
    }

    func resumeCurrentJob(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "pause"
            json["action"] = "resume"

            jobPost(httpClient: client, json: json, callback: callback)
        }
    }
    
    func cancelCurrentJob(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "cancel"
            
            jobPost(httpClient: client, json: json, callback: callback)
        }
    }
    
    // MARK: - Printer operations
    
    // Retrieves the current state of the printer. Returned information includes:
    // 1. temperature information (see also Retrieve the current tool state and Retrieve the current bed state)
    // 2. sd state (if available, see also Retrieve the current SD state)
    // 3. general printer state
    func printerState(callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            client.get("/api/printer") { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                // Check if there was an error
                if let _ = error {
                    NSLog("Error getting printer state. Error: \(error!.localizedDescription)")
                }
                callback(result, error, response)
            }
        }
    }
    
    func bedTargetTemperature(newTarget: Int, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "target"
            json["target"] = newTarget

            client.post("/api/printer/bed", json: json, expected: 204) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                callback(response.statusCode == 204, error, response)
            }
        }
    }

    func toolTargetTemperature(toolNumber: Int, newTarget: Int, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "target"
            let targets : NSMutableDictionary = NSMutableDictionary()
            targets["tool\(toolNumber)"] = newTarget
            json["targets"] = targets
         
            printerToolPost(httpClient: client, json: json, toolNumber: toolNumber, callback: callback)
        }
    }
    
    // Set the new flow rate for the requested extruder. Currently there is no way to read current flow rate value
    func toolFlowRate(toolNumber: Int, newFlowRate: Int, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            // We first need to select the tool and then set flow rate (using the selected tool)
            // This means that we need to make 2 HTTP requests
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "select"
            json["tool"] = "tool\(toolNumber)"
            
            // Select Tool to use to set flow rate
            printerToolPost(httpClient: client, json: json, toolNumber: toolNumber) { (success: Bool, error: Error?, response: HTTPURLResponse) in
                if success {
                    let json : NSMutableDictionary = NSMutableDictionary()
                    json["command"] = "flowrate"
                    json["factor"] = newFlowRate
                    // Select worked fine so now set new flow rate
                    self.printerToolPost(httpClient: client, json: json, toolNumber: toolNumber, callback: callback)
                } else {
                    callback(false, error, response)
                }
            }
        }
    }
    
    func extrude(toolNumber: Int, delta: Int, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            // We first need to select the tool and then extrude/retract (using the selected tool)
            // This means that we need to make 2 HTTP requests
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "select"
            json["tool"] = "tool\(toolNumber)"
            
            // Select Tool to use for extrude command
            printerToolPost(httpClient: client, json: json, toolNumber: toolNumber) { (success: Bool, error: Error?, response: HTTPURLResponse) in
                if success {
                    let json : NSMutableDictionary = NSMutableDictionary()
                    json["command"] = "extrude"
                    json["amount"] = delta
                    // Select worked fine so now request extrude/retract
                    self.printerToolPost(httpClient: client, json: json, toolNumber: toolNumber, callback: callback)
                } else {
                    callback(false, error, response)
                }
            }
        }
    }
    
    func sendCommand(gcode: String, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = gcode
            
            client.post("/api/printer/command", json: json, expected: 204) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                callback(response.statusCode == 204, error, response)
            }
        }
    }
    
    // MARK: - Print head operations (move operations)
    
    func move(x delta: Float, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "jog"
            json["x"] = delta
            
            printHeadPost(httpClient: client, json: json, callback: callback)
        }
    }
    
    func move(y delta: Float, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "jog"
            json["y"] = delta
            
            printHeadPost(httpClient: client, json: json, callback: callback)
        }
    }
    
    func move(z delta: Float, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "jog"
            json["z"] = delta
            
            printHeadPost(httpClient: client, json: json, callback: callback)
        }
    }
    
    // MARK: - File operations
    
    // Returns list of existing files
    func files(recursive: Bool = true, callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            client.get("/api/files?recursive=\(recursive)") { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                // Check if there was an error
                if let _ = error {
                    NSLog("Error getting files. Error: \(error!.localizedDescription)")
                }
                callback(result, error, response)
            }
        }
    }
    
    // Deletes the specified file
    func deleteFile(origin: String, path: String, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            client.delete("/api/files/\(origin)/\(path)") { (success: Bool, error: Error?, response: HTTPURLResponse) in
                // Check if there was an error
                if let _ = error {
                    NSLog("Error deleting file \(path). Error: \(error!.localizedDescription)")
                }
                callback(success, error, response)
            }
        }
    }
    
    // Prints the specified file
    func printFile(origin: String, path: String, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "select"
            json["print"] = true
            client.post("/api/files/\(origin)/\(path)", json: json, expected: 204) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                callback(response.statusCode == 204, error, response)
            }
        }
    }

    // MARK: - SD Card operations

    // Initialize the SD Card. Files will be read from the SD card during this operation
    func initSD(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "init"
            sdPost(httpClient: client, json: json, callback: callback)
        }
    }

    // Read files from the SD card during this operation. You will need to call #files() when this operation was run successfully
    func refreshSD(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "refresh"
            sdPost(httpClient: client, json: json, callback: callback)
        }
    }
    
    // Release the SD card from the printer. The reverse operation to initSD()
    func releaseSD(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "release"
            sdPost(httpClient: client, json: json, callback: callback)
        }
    }

    // MARK: - Fan operations
    
    // Set the new fan speed. We receive a value between 0 and 100 and need to convert to rante 0-255
    // There is no way to read current fan speed
    func fanSpeed(speed: Int, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        let newSpeed: Int = speed * 255 / 100
        let command = "M106 S\(newSpeed)"
        sendCommand(gcode: command, callback: callback)
    }

    // MARK: - Motor operations
    
    func disableMotor(axis: axis, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        let command = "M18 \(axis)"
        sendCommand(gcode: command, callback: callback)
    }
    
    // MARK: - Low level operations

    fileprivate func connectionPost(httpClient: HTTPClient, json: NSDictionary, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        httpClient.post("/api/connection", json: json, expected: 204) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
            callback(response.statusCode == 204, error, response)
        }
    }
    
    fileprivate func jobPost(httpClient: HTTPClient, json: NSDictionary, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        httpClient.post("/api/job", json: json, expected: 204) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
            callback(response.statusCode == 204, error, response)
        }
    }
    
    fileprivate func printHeadPost(httpClient: HTTPClient, json: NSDictionary, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        httpClient.post("/api/printer/printhead", json: json, expected: 204) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
            callback(response.statusCode == 204, error, response)
        }
    }
    
    fileprivate func printerToolPost(httpClient: HTTPClient, json: NSDictionary, toolNumber: Int, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        httpClient.post("/api/printer/tool", json: json, expected: 204) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
            callback(response.statusCode == 204, error, response)
        }
    }

    fileprivate func sdPost(httpClient: HTTPClient, json: NSDictionary, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        httpClient.post("/api/printer/sd", json: json, expected: 204) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
            callback(response.statusCode == 204, error, response)
        }
    }
}
