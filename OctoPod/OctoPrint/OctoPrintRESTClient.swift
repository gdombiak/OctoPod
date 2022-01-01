import Foundation

enum axis {
    case X
    case Y
    case Z
    case E
    case ALL
}

class OctoPrintRESTClient {

    var httpClient: HTTPClient?

    var preRequest: (() -> Void)? {
        get {
            return httpClient?.preRequest
        }
        set(block) {
            httpClient?.preRequest = block
        }
    }
    var postRequest: (() -> Void)?  {
        get {
            return httpClient?.postRequest
        }
        set(block) {
            httpClient?.postRequest = block
        }
    }
    var timeoutIntervalForRequest: TimeInterval {
        get {
            return httpClient?.timeoutIntervalForRequest ?? 0
        }
        set(value) {
            httpClient?.timeoutIntervalForRequest = value
        }
    }
    var timeoutIntervalForResource: TimeInterval {
        get {
            return httpClient?.timeoutIntervalForResource ?? 0
        }
        set(value) {
            httpClient?.timeoutIntervalForResource = value
        }
    }

    // MARK: - OctoPrint connection

    func connectToServer(serverURL: String, apiKey: String, username: String?, password: String?, preemptive: Bool) {
        httpClient = HTTPClient(serverURL: serverURL, apiKey: apiKey, username: username, password: password, preemptive: preemptive)
    }
    
    func disconnectFromServer() {
        httpClient = nil
    }
    
    func isConfigured() -> Bool {
        return httpClient != nil
    }
    
    // MARK: - Login operations
    
    /// Passive login has been added to OctoPrint 1.3.10 to increase security. Endpoint existed before
    /// but without passive mode. New version returns a "session" field that is used by websockets to
    /// allow websockets to work when Forcelogin Plugin is active (the default)
    func passiveLogin(callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["passive"] = true
            
            client.post("/api/login", json: json, expected: 200) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                // Check if there was an error
                if let _ = error {
                    NSLog("Error doing passive login. Error: \(error!.localizedDescription)")
                }
                callback(result, error, response)
            }
        }
    }
    
    /// Probes for application key workflow support
    /// - parameters:
    ///     - callback: success; error; http response
    ///     - success: true if application key is supported/enabled
    ///     - error: any error that happened making the HTTP request
    ///     - response: HTTP response
    func appkeyProbe(callback: @escaping (_ success: Bool, _ error: Error?, _ response: HTTPURLResponse) -> Void) {
        if let client = httpClient {
            client.get("/plugin/appkeys/probe") { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                // Check if there was an error
                if let _ = error {
                    NSLog("Error probing for workflow support. Error: \(error!.localizedDescription)")
                }
                callback(response.statusCode == 204, error, response)
            }
        }
    }

    /// Starts the authorization process to obtain an application key. Callback will receive the Location URL
    /// to poll or nil if process failed to start.
    /// - parameters:
    ///     - app: application identifier to use for the request, case insensitive
    ///     - callback: location; error; http response
    ///     - location: URL for polling
    ///     - error: any error that happened making the HTTP request
    ///     - response: HTTP response
    func appkeyRequest(app: String, callback: @escaping (_ location: String?, _ error: Error?, _ response: HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["app"] = app
            
            client.post("/plugin/appkeys/request", json: json, expected: 201) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                if response.statusCode == 201 {
                    if #available(iOS 13.0, watchOSApplicationExtension 6.0, *) {
                        callback(response.value(forHTTPHeaderField: "Location"), error, response)
                    } else {
                        // Fallback on earlier versions
                        let location = response.allHeaderFields["Location"] as? String
                        callback(location, error, response)
                    }
                } else {
                    callback(nil, error, response)
                }
            }
        }
    }

    /// Poll for decision on existing application key request.
    /// - parameters:
    ///     - location: URL to poll. URL was returned as an HTTP header when #appkeyRequest was executed
    ///     - callback: api_key;  keep polling; error; http response
    ///     - api_key: API key generated for the application
    ///     - retry: true if we need to keep polling for a decision
    ///     - error: any error that happened making the HTTP request
    ///     - response: HTTP response
    func appkeyPoll(location: String, callback: @escaping (_ api_key: String?, _ retry: Bool, _ error: Error?, _ response: HTTPURLResponse) -> Void) {
        if let client = httpClient {
            client.get(location) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                // Check if there was an error
                if let _ = error {
                    NSLog("Error polling for application key. Error: \(error!.localizedDescription)")
                }
                if response.statusCode == 202 {
                    // User did not decide yet. Keep polling
                    callback(nil, true, error, response)
                } else if response.statusCode == 200 {
                    // User accepted so return app key
                    if let json = result as? NSDictionary, let api_key = json["api_key"] as? String {
                        callback(api_key, false, error, response)
                    }
                } else if response.statusCode == 404 {
                    // request has been denied or timed out
                    callback(nil, false, error, response)
                } else {
                    // Some unknown error so keep polling
                    callback(nil, true, error, response)
                }
            }
        }
    }

    // MARK: - Version information
    
    /// Return OctoPrint's version information. This includes API version and server version
    func versionInformation(callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            client.get("/api/version") { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                // Check if there was an error
                if let _ = error {
                    NSLog("Error getting version information. Error: \(error!.localizedDescription)")
                }
                callback(result, error, response)
            }
        }
    }
    
    // MARK: - Connection operations
    
    /// Return connection status from OctoPrint to the 3D printer
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
    
    /// Ask OctoPrint to connect using default settings. We always get 204 status code (unless there was some network error)
    /// To know if OctoPrint was able to connect to the 3D printer then we need to check for its connection status
    func connectToPrinter(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "connect"
            
            connectionPost(httpClient: client, json: json, callback: callback)
        }
    }
    
    /// Ask OctoPrint to disconnect from the 3D printer. Use connection status to check if it was successful
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
                    NSLog("Error getting printer state for \(String(describing: client.serverURL)). Error: \(error!.localizedDescription)")
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
    
    /// There needs to be an active job that has been paused in order to be able to restart
    func restartCurrentJob(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "restart"
            
            jobPost(httpClient: client, json: json, callback: callback)
        }
    }

    // MARK: - Printer operations
    
    /// Retrieves the current state of the printer. Returned information includes:
    /// 1. temperature information (see also Retrieve the current tool state and Retrieve the current bed state)
    /// 2. sd state (if available, see also Retrieve the current SD state)
    /// 3. general printer state
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
    
    /**
     Sets target temperature for the printer’s heated chamber
     - Parameter newTarget: new chamber temperature to set
     - Parameter callback: callback to execute after HTTP request is done
     */
    func chamberTargetTemperature(newTarget: Int, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "target"
            json["target"] = newTarget
            
            client.post("/api/printer/chamber", json: json, expected: 204) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                callback(response.statusCode == 204, error, response)
            }
        }
    }
    
    /// Set the new flow rate for the requested extruder. Currently there is no way to read current flow rate value
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
    
    func extrude(toolNumber: Int, delta: Int, speed: Int?, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
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
                    if let speed = speed {
                        json["speed"] = speed
                    }
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
    
    func home(axes: Array<String>, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "home"
            json["axes"] = axes
            
            printHeadPost(httpClient: client, json: json, callback: callback)
        }
    }
    
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
    
    /// Set the feed rate factor using an integer argument
    func feedRate(factor: Int, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "feedrate"
            json["factor"] = factor
            
            printHeadPost(httpClient: client, json: json, callback: callback)
        }
    }

    // MARK: - File operations
    
    /// Returns list of existing files
    func files(location: String, recursive: Bool = true, callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            client.get("/api/files\(location)?recursive=\(recursive)") { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                // Check if there was an error
                if let _ = error {
                    NSLog("Error getting files. Error: \(error!.localizedDescription)")
                }
                callback(result, error, response)
            }
        }
    }
    
    /// Deletes the specified file
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
    
    /// Prints the specified file
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
    
    /// Uploads file to the specified location in OctoPrint's local file system
    /// If no folder is specified then file will be uploaded to root folder in OctoPrint
    func uploadFileToOctoPrint(path: String?, filename: String, fileContent: Data , callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let parameters: [String: String]? = path == nil ? nil : ["path": path!]
            client.upload("/api/files/local", parameters: parameters, filename: filename, fileContent: fileContent, expected: 201, callback: callback)
        }
    }
    
    /// Uploads file to the SD Card (OctoPrint will first upload to OctoPrint and then copy to SD Card so we will end up with a copy in OctoPrint as well)
    func uploadFileToSDCard(filename: String, fileContent: Data , callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            client.upload("/api/files/sdcard", parameters: nil, filename: filename, fileContent: fileContent, expected: 201, callback: callback)
        }
    }
    
    // MARK: - SD Card operations
    
    /// Initialize the SD Card. Files will be read from the SD card during this operation
    func initSD(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "init"
            sdPost(httpClient: client, json: json, callback: callback)
        }
    }
    
    /// Read files from the SD card during this operation. You will need to call #files() when this operation was run successfully
    func refreshSD(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "refresh"
            sdPost(httpClient: client, json: json, callback: callback)
        }
    }
    
    /// Release the SD card from the printer. The reverse operation to initSD()
    func releaseSD(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "release"
            sdPost(httpClient: client, json: json, callback: callback)
        }
    }

    // MARK: - Fan operations
    
    /// Set the new fan speed. We receive a value between 0 and 100 and need to convert to rante 0-255
    /// There is no way to read current fan speed
    func fanSpeed(speed: Int, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        let newSpeed: Int = speed * 255 / 100
        let command = "M106 S\(newSpeed)"
        sendCommand(gcode: command, callback: callback)
    }
    
    // MARK: - Motor operations
    
    func disableMotor(axis: axis, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        let command = axis == .ALL ? "M18" : "M18 \(axis)"
        sendCommand(gcode: command, callback: callback)
    }
    
    // MARK: - Settings operations
    
    func octoPrintSettings(callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            client.get("/api/settings") { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                // Check if there was an error
                if let _ = error {
                    NSLog("Error getting OctoPrint settings. Error: \(error!.localizedDescription)")
                }
                callback(result, error, response)
            }
        }
    }
    
    // MARK: - Printer Profile operations
    
    func printerProfiles(callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            client.get("/api/printerprofiles") { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                // Check if there was an error
                if let _ = error {
                    NSLog("Error getting printer profiles. Error: \(error!.localizedDescription)")
                }
                callback(result, error, response)
            }
        }
    }
    
    // MARK: - System Commands operations
    
    func systemCommands(callback: @escaping (Array<SystemCommand>?, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            client.get("/api/system/commands") { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                // Check if there was an error
                if let _ = error {
                    NSLog("Error getting system commands. Error: \(error!.localizedDescription)")
                }
                callback(self.parseSystemCommands(json: result), error, response)
            }
        }
    }
    
    func executeSystemCommand(command: SystemCommand, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            client.post("/api/system/commands/\(command.source)/\(command.action)") { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                callback(requested, error, response)
            }
        }
    }

    // MARK: - Timelapse operations
    
    /// Retrieve a list of timelapses
    func timelapses(callback: @escaping (Array<Timelapse>?, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            client.get("/api/timelapse") { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                // Check if there was an error
                if let _ = error {
                    NSLog("Error getting timelapses. Error: \(error!.localizedDescription)")
                }
                callback(self.parseTimelapses(json: result), error, response)
            }
        }
    }

    /// Delete the specified timelapse
    /// - Parameters:
    ///     - timelapse: Timelapse to delete
    ///     - callback: callback to execute after HTTP request is done
    func deleteTimelapse(timelapse: Timelapse, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            client.delete("/api/timelapse/\(timelapse.name)") { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                callback(requested, error, response)
            }
        }
    }
    
    /// Download specified timelapse file
    /// - Parameters:
    ///     - timelapse: Timelapse to delete
    ///     - progress: callback to execute while download is in progress
    ///     - completion: callback to execute after download is done
    func downloadTimelapse(timelapse: Timelapse, progress: @escaping (Int64, Int64) -> Void, completion: @escaping (Data?, Error?) -> Void) {
        if let client = httpClient {
            client.download("/api/timelapse/\(timelapse.name)", progress: progress) { (data: Data?, error: Error?) in
                // Check if there was an error
                if let _ = error {
                    NSLog("Error dowloading timelapse: \(timelapse.name). Error: \(error!.localizedDescription)")
                }
                completion(data, error)
            }
        }
    }


    // MARK: - Custom Controls operations
    
    func customControls(callback: @escaping (Array<Container>?, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            client.get("/api/printer/command/custom") { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                // Check if there was an error
                if let _ = error {
                    NSLog("Error getting custom controls. Error: \(error!.localizedDescription)")
                }
                callback(self.parseContainers(json: result), error, response)
            }
        }
    }
    
    func executeCustomControl(control: NSDictionary, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            client.post("/api/printer/command", json: control, expected: 204) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                callback(response.statusCode == 204, error, response)
            }
        }
    }
    
    // MARK: - Plugin updates operations

    /**
     Checks whether there are updates for installed plugins or not
     - Parameters:
         - callback: callback to execute after HTTP request is done
         - json: NSObject with returned JSON in case of a successful call
         - error: Optional error in case http request failed
         - response: HTTP Response
     */
    func checkPluginUpdates(callback: @escaping (_ json: NSObject?, _ error: Error?, _ response: HTTPURLResponse) -> Void) {
        if let client = httpClient {
            client.get("/plugin/softwareupdate/check") { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                // Check if there was an error
                if let _ = error {
                    NSLog("Error checking plugin updates. Error: \(error!.localizedDescription)")
                }
                callback(result, error, response)
            }
        }
    }


    // MARK: - PSU Control Plugin operations
    
    func turnPSU(on: Bool, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = on ? "turnPSUOn" : "turnPSUOff"
            client.post("/api/plugin/psucontrol", json: json, expected: 204) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                callback(response.statusCode == 204, error, response)
            }
        }
    }
    
    func getPSUState(callback: @escaping (Bool?, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "getPSUState"
            client.post("/api/plugin/psucontrol", json: json, expected: 200) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                // Check if there was an error
                if let _ = error {
                    NSLog("Error getting PSUState. Error: \(error!.localizedDescription)")
                }
                if let json = result as? NSDictionary {
                    if let isPSUOn = json["isPSUOn"] as? Bool {
                        callback(isPSUOn, error, response)
                        return
                    }
                }
                callback(nil, error, response)
            }
        }
    }
    
    // MARK: - IP Plug Plugin (TPLink Smartplug, Wemo, Domoticz, etc.)
    
    /// Instruct an IP plugin (e.g. TPLinkSmartplug, WemoSwitch, domoticz) to turn on/off the
    /// device with the specified IP address. If request was successful we get back a 204
    /// and the status is reported via websockets
    func turnIPPlug(plugin: String, on: Bool, plug: IPPlug, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        let json : NSMutableDictionary = NSMutableDictionary()
        json["command"] = on ? "turnOn" : "turnOff"
        json["ip"] = plug.ip
        if let idx = plug.idx {
            json["idx"] = idx
        }
        if let username = plug.username {
            json["username"] = username
        }
        if let password = plug.password {
            json["password"] = password
        }
        pluginCommand(plugin: plugin, json: json, callback: callback)
    }
    
    /// Instruct an IP plugin (e.g. TPLinkSmartplug, WemoSwitch, domoticz) to turn on/off the
    /// device with the specified IP address. If request was successful we get back a 204
    /// and the status is reported via websockets
    func turnIPPlug(plugin: String, on: Bool, plug: IPPlug, callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        let json : NSMutableDictionary = NSMutableDictionary()
        json["command"] = on ? "turnOn" : "turnOff"
        json["ip"] = plug.ip
        if let idx = plug.idx {
            json["idx"] = idx
        }
        if let username = plug.username {
            json["username"] = username
        }
        if let password = plug.password {
            json["password"] = password
        }
        pluginCommand(plugin: plugin, json: json, callback: callback)
    }
    
    /// Instruct an IP plugin to report the status of the device with the specified IP address
    /// If request was successful we get back a 204 and the status is reported via websockets
    func checkIPPlugStatus(plugin: String, plug: IPPlug, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        let json : NSMutableDictionary = NSMutableDictionary()
        json["command"] = "checkStatus"
        json["ip"] = plug.ip
        if let idx = plug.idx {
            json["idx"] = idx
        }
        if let username = plug.username {
            json["username"] = username
        }
        if let password = plug.password {
            json["password"] = password
        }
        pluginCommand(plugin: plugin, json: json, callback: callback)
    }

    /// Instruct an IP plugin to report the status of the device with the specified IP address
    /// If request was successful we get back a 204 and the status is reported via websockets
    func checkIPPlugStatus(plugin: String, plug: IPPlug, callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        let json : NSMutableDictionary = NSMutableDictionary()
        json["command"] = "checkStatus"
        json["ip"] = plug.ip
        if let idx = plug.idx {
            json["idx"] = idx
        }
        if let username = plug.username {
            json["username"] = username
        }
        if let password = plug.password {
            json["password"] = password
        }
        pluginCommand(plugin: plugin, json: json, callback: callback)
    }
    
    // MARK: - Cancel Object Plugin operations
    
    /// Get list of objects that are part of the current gcode being printed. Objects already cancelled will be part of the response
    func getCancelObjects(ignore: Array<String>, callback: @escaping (Array<CancelObject>?, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "objlist"
            client.post("/api/plugin/cancelobject", json: json, expected: 200) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                // Check if there was an error
                if let _ = error {
                    NSLog("Error getting list of objects that can be cancelled. Error: \(error!.localizedDescription)")
                }
                if let json = result as? NSDictionary {
                    if let jsonArray = json["list"] as? NSArray {
                        var cancelObjects: Array<CancelObject> = Array()
                        for case let item as NSDictionary in jsonArray {
                            if let cancelObject = CancelObject.parse(json: item), !ignore.contains(cancelObject.object) {
                                // Only add object if not present in ignored list
                                cancelObjects.append(cancelObject)
                            }
                        }
                        callback(cancelObjects, error, response)
                        return
                    }
                }
                callback(nil, error, response)
            }
        }
    }

    /// Cancel the requested object id.
    func cancelObject(id: Int, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "cancel"
            json["cancelled"] = id
            client.post("/api/plugin/cancelobject", json: json, expected: 204) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                callback(response.statusCode == 204, error, response)
            }
        }
    }
    
    // MARK: - Octorelay Plugin operations
    
    /// Get list of relays including their names and active status
    func getOctorelay(callback: @escaping (Array<Octorelay>?, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "listAllStatus"
            client.post("/api/plugin/octorelay", json: json, expected: 200) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                // Check if there was an error
                if let _ = error {
                    NSLog("Error getting list of relays. Error: \(error!.localizedDescription)")
                }
                if let json = result as? NSArray {
                    var octorelays: Array<Octorelay> = Array()
                    for case let item as NSDictionary in json {
                        if let octorelay = Octorelay.parse(json: item) {
                            octorelays.append(octorelay)
                        }
                    }
                    callback(octorelays, error, response)
                    return
                }
                callback(nil, error, response)
            }
        }
    }

    /// Switch (i.e. flip) relay status
    func switchRelay(id: String, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "update"
            json["pin"] = id
            client.post("/api/plugin/octorelay", json: json, expected: 200) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                callback(response.statusCode == 200, error, response)
            }
        }
    }

    // MARK: - OctoPod Plugin operations
    
    /**
     Register new APNS token so app can receive push notifications from OctoPod plugin
     */
    func registerAPNSToken(oldToken: String?, newToken: String, deviceName: String, printerID: String, printerName: String, languageCode: String, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "updateToken"
            json["oldToken"] = oldToken == nil ? "" : oldToken!
            json["newToken"] = newToken
            json["deviceName"] = deviceName
            json["printerID"] = printerID            
            json["printerName"] = printerName
            json["languageCode"] = languageCode
            client.post("/api/plugin/octopod", json: json, expected: 204) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                callback(response.statusCode == 204, error, response)
            }
        }
    }

    /**
     Register new APNS token so app can receive push notifications from OctoPod plugin
     - Parameter eventCode: code that identifies event that we want to snooze (eg. mmu-event)
     - Parameter minutes: number of minutes to snooze
     - Parameter callback: callback to execute when HTTP request is done
     - Parameter Flag that indicates if request was successfull
     */
    func snoozeAPNSEvents(eventCode: String, minutes: Int, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "snooze"
            json["eventCode"] = eventCode
            json["minutes"] = minutes
            client.post("/api/plugin/octopod", json: json, expected: 204) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                callback(response.statusCode == 204, error, response)
            }
        }
    }
    
    /// Adds or removes notification for specified layer. DisplayLayerProgress and OctoPod plugins are required
    ///
    /// - parameters:
    ///     - layer: number of layer to be notified
    ///     - add: Add or Delete notification for the specified layer
    ///     - callback: callback to execute when HTTP request is done
    func layerNotification(layer: String, add: Bool, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = add ? "addLayer" : "removeLayer"
            json["layer"] = layer
            client.post("/api/plugin/octopod", json: json, expected: 204) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                callback(response.statusCode == 204, error, response)
            }
        }
    }

    /// Returns layers for which a push notification will be sent. DisplayLayerProgress and OctoPod plugins are required
    ///
    /// - parameters:
    ///     - callback: callback to execute when HTTP request is done
    func getLayerNotifications(callback: @escaping (Array<String>?, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "getLayers"
            client.post("/api/plugin/octopod", json: json, expected: 200) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                // Check if there was an error
                if let _ = error {
                    NSLog("Error getting list of layer notifications. Error: \(error!.localizedDescription)")
                }
                if let json = result as? NSDictionary {
                    if let jsonArray = json["layers"] as? Array<String> {
                        callback(jsonArray, error, response)
                        return
                    }
                }
                callback(nil, error, response)
            }
        }
    }

    /// Returns history of System on a chip (SoC) temperatures from OctoPod plugin (if installed)
    ///
    /// - parameters:
    ///     - callback: callback to execute when HTTP request is done
    func getSoCTemperatures(callback: @escaping (Array<SoCTempHistory.Temp>?, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "getSoCTemps"
            client.post("/api/plugin/octopod", json: json, expected: 200) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                // Check if there was an error
                if let _ = error {
                    NSLog("Error getting history of SoC temps from OctoPod plugin. Error: \(error!.localizedDescription)")
                }
                if let jsonArray = result as? NSArray {
                    var retrieved: Array<SoCTempHistory.Temp> = Array()
                    for case let item as NSDictionary in jsonArray {
                        var temp = SoCTempHistory.Temp()
                        temp.parseTemps(data: item)
                        retrieved.append(temp)
                    }
                    callback(retrieved, error, response)
                    return
                }
                callback(nil, error, response)
            }
        }
    }

    // MARK: - Palette 2 Plugin
    
    /// Request Palette 2 plugin to send its status via websockets. If request was successful we get back a 200
    /// and status is reported via websockets
    /// - parameters:
    ///     - plugin: Identifier of the Palette 2 plugin. See Plugins structure
    func palette2Status(plugin: String, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        let json : NSMutableDictionary = NSMutableDictionary()
        json["command"] = "uiUpdate"
        pluginCommand(plugin: plugin, json: json) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
            callback(response.statusCode == 200, error, response)
        }
    }
    
    /// Request Palette 2 plugin to return ping history. If request was successful we get back in the response this information. It relies
    /// on new API call added to Palette2 plugin (i.e. a new version is needed)
    /// - parameters:
    ///     - plugin: Identifier of the Palette 2 plugin. See Plugins structure
    func palette2PingHistory(plugin: String, callback: @escaping ((number: String, percent: String, variance: String)?, (max: String, average: String, min: String)?, Error?, HTTPURLResponse) -> Void) {
        let json : NSMutableDictionary = NSMutableDictionary()
        json["command"] = "getPingHistory"
        pluginCommand(plugin: plugin, json: json) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
            // Check if there was an error
            if let _ = error {
                NSLog("Error getting ping history from Palette2. Error: \(error!.localizedDescription)")
            }
            if let json = result as? NSDictionary {
//                let pings = [["number": Int(1), "percent": 99.99], ["number": Int(2), "percent": 99.39], ["number": Int(3), "percent": 99.69]]
                if let pings = json["data"] as? Array<Dictionary<String,Any>> {
                    if let lastPing = Palette2Utils.pingPongMessage(history: pings, index: pings.count - 1, reversed: false), let pingStats = Palette2Utils.pingPongVarianceStats(history: pings, reversed: false) {
                        callback(lastPing, pingStats, error, response)
                        return
                    }
                }
            }
            callback(nil, nil, error, response)
        }
    }
    
    /// Request Palette 2 plugin to send list of available ports via websockets. These are the ports available on
    /// the server where OctoPrint runs so that Palette 2 can connect. If request was successful we get back a 200
    /// and status is reported via websockets
    /// - parameters:
    ///     - plugin: Identifier of the Palette 2 plugin. See Plugins structure
    func palette2Ports(plugin: String, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        let json : NSMutableDictionary = NSMutableDictionary()
        json["command"] = "displayPorts"
        json["condition"] = "opening"  // Pass this parameter so that autoconnect is turned off
        pluginCommand(plugin: plugin, json: json) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
            callback(response.statusCode == 200, error, response)
        }
    }
    
    /// Request Palette 2 plugin to connect to Palette device. If request was successful we get back a 200
    /// and status is reported via websockets
    /// - parameters:
    ///     - plugin: Identifier of the Palette 2 plugin. See Plugins structure
    ///     - port: Port that Palette device is connected to on the OctoPrint server
    func palette2Connect(plugin: String, port: String?, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        let json : NSMutableDictionary = NSMutableDictionary()
        json["command"] = "connectOmega"
        if let port = port {
            json["port"] = port
        }
        pluginCommand(plugin: plugin, json: json) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
            callback(response.statusCode == 200, error, response)
        }
    }

    /// Request Palette 2 plugin to disconnect from Palette device. If request was successful we get back a 200
    /// and status is reported via websockets
    /// - parameters:
    ///     - plugin: Identifier of the Palette 2 plugin. See Plugins structure
    func palette2Disconnect(plugin: String, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        let json : NSMutableDictionary = NSMutableDictionary()
        json["command"] = "disconnectPalette2"
        pluginCommand(plugin: plugin, json: json) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
            callback(response.statusCode == 200, error, response)
        }
    }
    
    /// Request Palette 2 plugin to tell Palette device to start printing. If request was successful we
    /// get back a 200
    /// - parameters:
    ///     - plugin: Identifier of the Palette 2 plugin. See Plugins structure
    func palette2Print(plugin: String, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        let json : NSMutableDictionary = NSMutableDictionary()
        json["command"] = "startPrint"
        pluginCommand(plugin: plugin, json: json) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
            callback(response.statusCode == 200, error, response)
        }
    }
    
    /// Request Palette 2 plugin to tell Palette device to perform a cut. If request was successful we
    /// get back a 200
    /// - parameters:
    ///     - plugin: Identifier of the Palette 2 plugin. See Plugins structure
    func palette2Cut(plugin: String, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        let json : NSMutableDictionary = NSMutableDictionary()
        json["command"] = "sendCutCmd"
        pluginCommand(plugin: plugin, json: json) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
            callback(response.statusCode == 200, error, response)
        }
    }
    
    /// Request Palette 2 plugin to tell Palette device to perform a clear. If request was successful we
    /// get back a 200
    /// - parameters:
    ///     - plugin: Identifier of the Palette 2 plugin. See Plugins structure
    func palette2Clear(plugin: String, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        let json : NSMutableDictionary = NSMutableDictionary()
        json["command"] = "clearPalette2"
        pluginCommand(plugin: plugin, json: json) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
            callback(response.statusCode == 200, error, response)
        }
    }
    
    // MARK: - Enclosure Plugin
    
    /// Request enclosure plugin to refresh UI. This will cause plugin to send values for input and output elements
    func refreshEnclosureStatus(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            client.post("/plugin/enclosure/update") { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                callback(requested, error, response)
            }
        }
    }
    
    /// Returns the queried GPIO value for the specified GPIO output
    func getEnclosureGPIOStatus(index_id: Int16, callback: @escaping (Bool?, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            client.get("/plugin/enclosure/outputs/\(index_id)") { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                // Check if there was an error
                if let _ = error {
                    NSLog("Error getting enclosure GPIO status. Error: \(error!.localizedDescription)")
                    callback(nil, error, response)
                } else if response.statusCode == 200 {
                    if let jsonDict = result as? NSDictionary {
                        if let currentValue = jsonDict["current_value"] as? Int {
                            callback(currentValue == 1, error, response)
                            return
                        }
                    }
                    NSLog("Error getting enclosure GPIO status. Unexpected response body: \(String(describing: result))")
                    callback(nil, error, response)
                } else {
                    NSLog("Error getting enclosure GPIO status. HTTP status: \(response.statusCode)")
                    callback(nil, error, response)
                }
            }
        }
    }
    
    /// Change status of GPIO pin via Enclosure plugin
    func changeEnclosureGPIO(index_id: Int16, status: Bool, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["status"] = status
            client.patch("/plugin/enclosure/outputs/\(index_id)", json: json, expected: 204) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                callback(response.statusCode == 204, error, response)
            }
        }
    }

    /// Change PWM value via Enclosure plugin
    func changeEnclosurePWM(index_id: Int16, dutyCycle: Int, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["duty_cycle"] = dutyCycle
            client.patch("/plugin/enclosure/pwm/\(index_id)", json: json, expected: 204) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                callback(response.statusCode == 204, error, response)
            }
        }
    }
    
    /// Change temperature or humidity control value via Enclosure plugin
    func changeEnclosureTempControl(index_id: Int16, temp: Int, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["temperature"] = temp
            client.patch("/plugin/enclosure/temperature/\(index_id)", json: json, expected: 204) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                callback(response.statusCode == 204, error, response)
            }
        }
    }
    
    // MARK: - PrusaSlicer Thumbnails & Ultimaker Format Package Plugins

    /// Returns content of thumbnail image. This informatin is only available when PrusaSlicer was configured properly
    /// and PrusaSlicer Thumbnails plugin is installed
    func getThumbnailImage(path: String, callback: @escaping (Data?, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let correctedPath = path.starts(with: "/") ? path : "/\(path)"  // Old versions of plugins started with / 
            client.getData(correctedPath, callback: callback)
        }
    }

    // MARK: - FilamentManager Plugin
    
    /// Returns current filament selection for each extruder
    func filamentSelections(callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            client.get("/plugin/filamentmanager/selections") { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                // Check if there was an error
                if let _ = error {
                    NSLog("Error getting filamentmanager selections. Error: \(error!.localizedDescription)")
                }
                callback(result, error, response)
            }
        }
    }

    /// Returns configured filament spools. Answer also includes profile information (vendor and filament type)
    func filamentSpools(callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            client.get("/plugin/filamentmanager/spools") { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                // Check if there was an error
                if let _ = error {
                    NSLog("Error getting filamentmanager spools. Error: \(error!.localizedDescription)")
                }
                callback(result, error, response)
            }
        }
    }
    
    /// Changes filament selected for specified extruder
    func changeFilamentSelection(toolNumber: Int, spoolId: Int, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["selection"] = ["tool": toolNumber, "spool": ["id": spoolId]]
            client.patch("/plugin/filamentmanager/selections/\(toolNumber)", json: json, expected: 200) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                callback(response.statusCode == 200, error, response)
            }
        }
    }

    // MARK: - DisplayLayerProgress Plugin
    
    /// Ask DisplayLayerProgress to send latest status via websockets
    func refreshDisplayLayerProgress(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            client.get("/api/plugin/DisplayLayerProgress") { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                callback(response.statusCode == 204, error, response)
            }
        }
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

    fileprivate func pluginCommand(plugin: String, json: NSDictionary, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            client.post("/api/plugin/\(plugin)", json: json, expected: 204) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                callback(response.statusCode == 204, error, response)
            }
        }
    }
    
    fileprivate func pluginCommand(plugin: String, json: NSDictionary, callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            client.post("/api/plugin/\(plugin)", json: json, expected: 200) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                callback(result, error, response)
            }
        }
    }
    
    // MARK: - Private - System Commands functions

    fileprivate func parseSystemCommands(json: NSObject?)  -> Array<SystemCommand>? {
        if let jsonDict = json as? NSDictionary {
            var commands: Array<SystemCommand> = Array()
            if let jsonArray = jsonDict["core"] as? NSArray {
                for case let item as NSDictionary in jsonArray {
                    if let command = parseSystemCommand(json: item) {
                        commands.append(command)
                    }
                }
            }
            if let jsonArray = jsonDict["custom"] as? NSArray {
                for case let item as NSDictionary in jsonArray {
                    if let command = parseSystemCommand(json: item) {
                        commands.append(command)
                    }
                }
            }
            return commands
        }
        return nil
    }

    fileprivate func parseSystemCommand(json: NSDictionary) -> SystemCommand? {
        if let action = json["action"] as? String, let name = json["name"] as? String, let source = json["source"] as? String {
            if action == "divider" {
                // These commands should have no name so should not reach here but just in case we skip them here too
                return nil
            }
            return SystemCommand(name: name, action: action, source: source)
        }
        return nil
    }
    
    // MARK: - Private - Timelapses functions
    fileprivate func parseTimelapses(json: NSObject?)  -> Array<Timelapse>? {
        if let jsonDict = json as? NSDictionary {
            var timelapses: Array<Timelapse> = Array()
            if let jsonArray = jsonDict["files"] as? NSArray {
                for case let item as NSDictionary in jsonArray {
                    if let timelapse = parseTimelapse(json: item) {
                        timelapses.append(timelapse)
                    }
                }
            }
            return timelapses
        }
        return nil
    }
    
    fileprivate func parseTimelapse(json: NSDictionary) -> Timelapse? {
        if let name = json["name"] as? String, let size = json["size"] as? String, let bytes = json["bytes"] as? Int, let date = json["date"] as? String, let url = json["url"] as? String {
            return Timelapse(name: name, size: size, bytes: bytes, date: date, url: url)
        }
        return nil
    }
    
    // MARK: - Private - Custom Controls functions
    
    fileprivate func parseContainers(json: NSObject?) -> Array<Container>? {
        if let jsonDict = json as? NSDictionary {
            if let jsonArray = jsonDict["controls"] as? NSArray {
                var containers: Array<Container> = Array()
                for case let item as NSDictionary in jsonArray {
                    if let container = parseContainer(parentPath: "/", json: item) {
                        containers.append(container)
                    }
                }
                return containers
            }
        }
        return nil
    }
    
    fileprivate func parseContainer(parentPath: String, json: NSDictionary) -> Container? {
        if let children = json["children"] as? NSArray {
            var newName: String = "No name"
            if let name = json["name"] as? String {
                newName = name
            }
            
            let myPath = parentPath + newName
            
            var newChildren: Array<CustomControl> = Array()
            for case let child as NSDictionary in children {
                if let _ = child["children"] {
                    // Child is a Container
                    if let container = parseContainer(parentPath: myPath + "/", json: child) {
                        newChildren.append(container)
                    }
                }
                if let _ = child["script"] {
                    // Child is a Script
                    if let script = parseScript(json: child) {
                        newChildren.append(script)
                    }
                }
                if child["command"] != nil || child["commands"] != nil {
                    // Child is a Command
                    if let command = parseCommand(json: child) {
                        newChildren.append(command)
                    }
                }
            }
            return Container(path: myPath, name: newName, children: newChildren)
        }
        // Should not happen unless JSON has an unexpected format
        NSLog("Ignoring bogus container: \(json)")
        return nil
    }
    
    fileprivate func parseScript(json: NSDictionary) -> Script? {
        if let name = json["name"] as? String, let script = json["script"] as? String {
            var newConfirm: String?
            var newInput: Array<ControlInput>?
            if let confirm = json["confirm"] as? String {
                newConfirm = confirm
            }
            if let input = json["input"] as? NSArray {
                newInput = Array()
                for case let item as NSDictionary in input {
                    if let newControlInput = parseControlInput(json: item) {
                        newInput?.append(newControlInput)
                    }
                }
            }
            return Script(name: name, script: script, input: newInput, confirm: newConfirm)
        }
        // Should not happen unless JSON has an unexpected format
        NSLog("Ignoring bogus script: \(json)")
        return nil
    }
    
    fileprivate func parseCommand(json: NSDictionary) -> Command? {
        if let name = json["name"] as? String {
            var newConfirm: String?
            var newInput: Array<ControlInput>?
            
            if let confirm = json["confirm"] as? String {
                newConfirm = confirm
            }
            if let input = json["input"] as? NSArray {
                newInput = Array()
                for case let item as NSDictionary in input {
                    if let newControlInput = parseControlInput(json: item) {
                        newInput?.append(newControlInput)
                    }
                }
            }
            
            let command = Command(name: name, input: newInput, confirm: newConfirm)
            
            if let gcodeCommand = json["command"] as? String {
                command.command = gcodeCommand
            } else if let gcodeCommands = json["commands"] as? NSArray {
                var newCommands: Array<String> = Array()
                for case let gcodeCommand as String in gcodeCommands {
                    if !gcodeCommand.isEmpty {
                        // Ignore empty commands
                        newCommands.append(gcodeCommand)
                    }
                }
                command.commands = newCommands
            } else {
                // Found bogus JSON so ignore command
                NSLog("Ignoring bogus command: \(json)")
                return nil
            }
            
            return command
        }
        // Should not happen unless JSON has an unexpected format
        NSLog("Ignoring bogus command: \(json)")
        return nil
    }
    
    fileprivate func parseControlInput(json: NSDictionary) -> ControlInput? {
        if let name = json["name"] as? String, let parameter = json["parameter"] as? String {
            var defaultValue: AnyObject? = nil
            if let value = json["default"] as? String {
                defaultValue = value as AnyObject
            } else if let value = json["default"] as? Int {
                defaultValue = value as AnyObject
            } else if let value = json["default"] as? Double {
                defaultValue = value as AnyObject
            }
            let controlInput = ControlInput(name: name, parameter: parameter)
            
            if let slider = json["slider"] as? NSDictionary {
                controlInput.hasSlider = true
                if let sliderMax = slider["max"] as? String {
                    controlInput.slider_max = sliderMax
                } else if let sliderMax = slider["max"] as? NSNumber {
                    controlInput.slider_max = sliderMax.stringValue
                } else {
                    controlInput.slider_max = "255"
                }
                if let sliderMin = slider["min"] as? String {
                    controlInput.slider_min = sliderMin
                } else if let sliderMin = slider["min"] as? NSNumber {
                    controlInput.slider_min = sliderMin.stringValue
                } else {
                    controlInput.slider_min = "0"
                }
                if let sliderStep = slider["step"] as? String {
                    controlInput.slider_step = sliderStep
                } else if let sliderStep = slider["step"] as? NSNumber {
                    controlInput.slider_step = sliderStep.stringValue
                } else {
                    controlInput.slider_step = "1"
                }
                // Safety check to make sure there is a default value (should be one already but just in case)
                if defaultValue == nil {
                    defaultValue = controlInput.slider_min!.contains(".") ? Float(controlInput.slider_min!) as AnyObject : Int(controlInput.slider_min!) as AnyObject
                }
            }
            controlInput.defaultValue = defaultValue
            controlInput.value = defaultValue
            return controlInput
        }
        // Should not happen unless JSON has an unexpected format
        NSLog("Ignoring bogus ControlInput: \(json)")
        return nil
    }}
