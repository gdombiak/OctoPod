import Foundation
import UIKit

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
    
    var printerManager: PrinterManager!
    var httpClient: HTTPClient?
    var webSocketClient: WebSocketClient?
    
    let terminal = Terminal()
    let tempHistory = TempHistory()
    
    var delegates: Array<OctoPrintClientDelegate> = Array()
    var octoPrintSettingsDelegates: Array<OctoPrintSettingsDelegate> = Array()
    var printerProfilesDelegates: Array<PrinterProfilesDelegate> = Array()
    var octoPrintPluginsDelegates: Array<OctoPrintPluginsDelegate> = Array()

    // Remember last CurrentStateEvent that was reported from OctoPrint (via websockets)
    var lastKnownState: CurrentStateEvent?
    
    init(printerManager: PrinterManager) {
        self.printerManager = printerManager
    }
    
    // MARK: - OctoPrint server connection
    
    // Connect to OctoPrint server and gather printer state
    // A websocket connection will be attempted to get real time updates from OctoPrint
    // An HTTPClient is created for sending requests to OctoPrint
    func connectToServer(printer: Printer) {
        // Clean up any known printer state
        lastKnownState = nil
        
        // Create and keep httpClient while default printer does not change
        httpClient = HTTPClient(printer: printer)
        
        if webSocketClient?.isConnected(printer: printer) == true {
            // Do nothing since we are already connected to the default printer
            return
        }
        
        for delegate in delegates {
            delegate.notificationAboutToConnectToServer()
        }
        
        // Clean up any temp history
        tempHistory.clear()
        
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
        
        // Verify that last known settings are still current
        reviewOctoPrintSettings(printer: printer)
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
        // Track event as last known state. Will be reset when changing printers or on app cold startup
        lastKnownState = event
        // Notify the terminal that OctoPrint and/or Printer state has changed
        terminal.currentStateUpdated(event: event)
        // Track temp history
        if event.bedTempActual != nil || event.tool0TempActual != nil {
            var temp = TempHistory.Temp()
            temp.parseTemps(event: event)
            tempHistory.addTemp(temp: temp)
        }
        // Notify other listeners that OctoPrint and/or Printer state has changed
        for delegate in delegates {
            delegate.printerStateUpdated(event: event)
        }
    }
    
    // Notification that contains history of temperatures. This information is received once after
    // websocket connection was established. #currentStateUpdated contains new temps after this event
    func historyTemp(history: Array<TempHistory.Temp>) {
        tempHistory.addHistory(history: history)
    }
    
    // Notifcation that OctoPrint's settings has changed
    func octoPrintSettingsUpdated() {
        if let printer = printerManager.getDefaultPrinter() {
            // Verify that last known settings are still current
            reviewOctoPrintSettings(printer: printer)
        }
    }
    
    // Notification sent by plugin via websockets
    // plugin - identifier of the OctoPrint plugin
    // data - whatever JSON data structure sent by the plugin
    //
    // Example: {data: {isPSUOn: false, hasGPIO: true}, plugin: "psucontrol"}
    func pluginMessage(plugin: String, data: NSDictionary) {
        // Notify other listeners that we connected to OctoPrint
        for delegate in octoPrintPluginsDelegates {
            delegate.pluginMessage(plugin: plugin, data: data)
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
    
    // There needs to be an active job that has been paused in order to be able to restart
    func restartCurrentJob(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "restart"
            
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
    
    // Set the feed rate factor using an integer argument
    func feedRate(factor: Int, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let json : NSMutableDictionary = NSMutableDictionary()
            json["command"] = "feedrate"
            json["factor"] = factor
            
            printHeadPost(httpClient: client, json: json, callback: callback)
        }
    }
    
    // MARK: - File operations
    
    // Returns list of existing files
    func files(folder: PrintFile? = nil, recursive: Bool = true, callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let location = folder == nil ? "" : "/\(folder!.origin!)/\(folder!.path!)"
            client.get("/api/files\(location)?recursive=\(recursive)") { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
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
    
    // Uploads file to the specified location in OctoPrint's local file system
    // If no folder is specified then file will be uploaded to root folder in OctoPrint
    func uploadFileToOctoPrint(folder: PrintFile? = nil, filename: String, fileContent: Data , callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            let parameters: [String: String]? = folder == nil ? nil : ["path": "\(folder!.path!)"]
            client.upload("/api/files/local", parameters: parameters, filename: filename, fileContent: fileContent, expected: 201, callback: callback)
        }
    }
    
    // Uploads file to the SD Card (OctoPrint will first upload to OctoPrint and then copy to SD Card so we will end up with a copy in OctoPrint as well)
    func uploadFileToSDCard(filename: String, fileContent: Data , callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            client.upload("/api/files/sdcard", parameters: nil, filename: filename, fileContent: fileContent, expected: 201, callback: callback)
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
    
    // Instruct an IP plugin (e.g. TPLinkSmartplug, WemoSwitch, domoticz) to turn on/off the
    // device with the specified IP address. If request was successful we get back a 204
    // and the status is reported via websockets
    func turnIPPlug(plugin: String, on: Bool, plug: Printer.IPPlug, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
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
    
    // Instruct an IP plugin to report the status of the device with the specified IP address
    // If request was successful we get back a 204 and the status is reported via websockets
    func checkIPPlugStatus(plugin: String, plug: Printer.IPPlug, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
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
    
    // MARK: - Delegates operations
    
    func remove(octoPrintClientDelegate toRemove: OctoPrintClientDelegate) {
        delegates = delegates.filter({ (delegate) -> Bool in
            return delegate !== toRemove
        })
    }
    
    func remove(octoPrintSettingsDelegate toRemove: OctoPrintSettingsDelegate) {
        octoPrintSettingsDelegates = octoPrintSettingsDelegates.filter({ (delegate) -> Bool in
            return delegate !== toRemove
        })
    }
    
    func remove(printerProfilesDelegate toRemove: PrinterProfilesDelegate) {
        printerProfilesDelegates = printerProfilesDelegates.filter({ (delegate) -> Bool in
            return delegate !== toRemove
        })
    }
    
    func remove(octoPrintPluginsDelegate toRemove: OctoPrintPluginsDelegate) {
        octoPrintPluginsDelegates = octoPrintPluginsDelegates.filter({ (delegate) -> Bool in
            return delegate !== toRemove
        })
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
    
    // MARK: - Private - Settings functions
    
    fileprivate func reviewOctoPrintSettings(printer: Printer) {
        // Update Printer from /api/settings information
        octoPrintSettings { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
            if response.statusCode == 200 {
                if let json = result as? NSDictionary {
                    self.updatePrinterFromSettings(printer: printer, json: json)
                }
            }
        }
        // Update Printer from /api/printerprofiles information
        reviewPrinterProfile(printer: printer)
    }
    
    fileprivate func updatePrinterFromSettings(printer: Printer, json: NSDictionary) {
        if let feature = json["feature"] as? NSDictionary {
            if let sdSupport = feature["sdSupport"] as? Bool {
                if printer.sdSupport != sdSupport {
                    // Update sd support
                    printer.sdSupport = sdSupport
                    // Persist updated printer
                    printerManager.updatePrinter(printer)

                    // Notify listeners of change
                    for delegate in octoPrintSettingsDelegates {
                        delegate.sdSupportChanged(sdSupport: sdSupport)
                    }
                }
            }
        }

        if let webcam = json["webcam"] as? NSDictionary {
            if let flipH = webcam["flipH"] as? Bool, let flipV = webcam["flipV"] as? Bool, let rotate90 = webcam["rotate90"] as? Bool {
                let newOrientation = calculateImageOrientation(flipH: flipH, flipV: flipV, rotate90: rotate90)
                if printer.cameraOrientation != newOrientation.rawValue {
                    // Update camera orientation
                    printer.cameraOrientation = Int16(newOrientation.rawValue)
                    // Persist updated printer
                    printerManager.updatePrinter(printer)

                    // Notify listeners of change
                    for delegate in octoPrintSettingsDelegates {
                        delegate.cameraOrientationChanged(newOrientation: newOrientation)
                    }
                }
            }
            if let streamUrl = webcam["streamUrl"] as? String {
                if printer.streamUrl != streamUrl {
                    // Update path to camera hosted by OctoPrint
                    printer.streamUrl = streamUrl
                    // Persist updated printer
                    printerManager.updatePrinter(printer)
                    
                    // Notify listeners of change
                    for delegate in octoPrintSettingsDelegates {
                        delegate.cameraPathChanged(streamUrl: streamUrl)
                    }
                }
            }
        }
        
        if let plugins = json["plugins"] as? NSDictionary {
            updatePrinterFromPlugins(printer: printer, plugins: plugins)
        }
    }
    
    fileprivate func updatePrinterFromPlugins(printer: Printer, plugins: NSDictionary) {
        updatePrinterFromMultiCamPlugin(printer: printer, plugins: plugins)
        updatePrinterFromPSUControlPlugin(printer: printer, plugins: plugins)
        updatePrinterFromTPLinkSmartplugPlugin(printer: printer, plugins: plugins)
        updatePrinterFromWemoPlugin(printer: printer, plugins: plugins)
        updatePrinterFromDomoticzPlugin(printer: printer, plugins: plugins)
        updatePrinterFromTasmotaPlugin(printer: printer, plugins: plugins)
    }
    
    fileprivate func updatePrinterFromMultiCamPlugin(printer: Printer, plugins: NSDictionary) {
        // Check if MultiCam plugin is installed. If so then copy URL to cameras so there is
        // no need to reenter this information
        var camerasURLs: Array<String> = Array()
        if let multicam = plugins[Plugins.MULTICAM] as? NSDictionary {
            if let profiles = multicam["multicam_profiles"] as? NSArray {
                for case let profile as NSDictionary in profiles {
                    if let url = profile["URL"] as? String {
                        camerasURLs.append(url)
                    }
                }
            }
        }
        // Check if url to cameras has changed
        var update = false
        if let existing = printer.cameras {
            update = !existing.elementsEqual(camerasURLs)
        } else {
            update = true
        }
        
        if update {
            // Update array
            printer.cameras = camerasURLs
            // Persist updated printer
            printerManager.updatePrinter(printer)
            
            // Notify listeners of change
            for delegate in octoPrintSettingsDelegates {
                delegate.camerasChanged(camerasURLs: camerasURLs)
            }
        }
    }
    
    fileprivate func updatePrinterFromPSUControlPlugin(printer: Printer, plugins: NSDictionary) {
        var installed = false
        if let _ = plugins[Plugins.PSU_CONTROL] as? NSDictionary {
            // PSUControl plugin is installed
            installed = true
        }
        if printer.psuControlInstalled != installed {
            // Update flag that tracks if PSU Control plugin is installed
            printer.psuControlInstalled = installed
            // Persist updated printer
            printerManager.updatePrinter(printer)
            
            // Notify listeners of change
            for delegate in octoPrintSettingsDelegates {
                delegate.psuControlAvailabilityChanged(installed: installed)
            }
        }
    }
    
    fileprivate func updatePrinterFromTPLinkSmartplugPlugin(printer: Printer, plugins: NSDictionary) {
        // Check if TPLinkSmartplug plugin is installed. If so then copy plugs information so there is
        // no need to reenter this information
        updatePrinterFromIPPlugPlugin(printer: printer, plugins: plugins, plugin: Plugins.TP_LINK_SMARTPLUG, getterPlugs: { (printer: Printer) -> Array<Printer.IPPlug>? in
            return printer.getTPLinkSmartplugs()
        }) { (printer: Printer, plugs: Array<Printer.IPPlug>) in
            printer.setTPLinkSmartplugs(plugs: plugs)
        }
    }
    
    fileprivate func updatePrinterFromWemoPlugin(printer: Printer, plugins: NSDictionary) {
        // Check if Wemo plugin is installed. If so then copy plugs information so there is
        // no need to reenter this information
        updatePrinterFromIPPlugPlugin(printer: printer, plugins: plugins, plugin: Plugins.WEMO_SWITCH, getterPlugs: { (printer: Printer) -> Array<Printer.IPPlug>? in
            return printer.getWemoPlugs()
        }) { (printer: Printer, plugs: Array<Printer.IPPlug>) in
            printer.setWemoPlugs(plugs: plugs)
        }

    }
    
    fileprivate func updatePrinterFromDomoticzPlugin(printer: Printer, plugins: NSDictionary) {
        // Check if Domoticz plugin is installed. If so then copy plugs information so there is
        // no need to reenter this information
        updatePrinterFromIPPlugPlugin(printer: printer, plugins: plugins, plugin: Plugins.DOMOTICZ, getterPlugs: { (printer: Printer) -> Array<Printer.IPPlug>? in
            return printer.getDomoticzPlugs()
        }) { (printer: Printer, plugs: Array<Printer.IPPlug>) in
            printer.setDomoticzPlugs(plugs: plugs)
        }
    }
    
    fileprivate func updatePrinterFromTasmotaPlugin(printer: Printer, plugins: NSDictionary) {
        // Check if Tasmota plugin is installed. If so then copy plugs information so there is
        // no need to reenter this information
        updatePrinterFromIPPlugPlugin(printer: printer, plugins: plugins, plugin: Plugins.TASMOTA, getterPlugs: { (printer: Printer) -> Array<Printer.IPPlug>? in
            return printer.getTasmotaPlugs()
        }) { (printer: Printer, plugs: Array<Printer.IPPlug>) in
            printer.setTasmotaPlugs(plugs: plugs)
        }
    }
    
    fileprivate func updatePrinterFromIPPlugPlugin(printer: Printer, plugins: NSDictionary, plugin: String, getterPlugs: ((Printer) ->  Array<Printer.IPPlug>?), setterPlugs: ((Printer, Array<Printer.IPPlug>) -> Void)) {
        // Check if TPLinkSmartplug plugin is installed. If so then copy plugs information so there is
        // no need to reenter this information
        var plugs: Array<Printer.IPPlug> = []
        if let tplinksmartplug = plugins[plugin] as? NSDictionary {
            if let arrSmartplugs = tplinksmartplug["arrSmartplugs"] as? NSArray {
                for case let plug as NSDictionary in arrSmartplugs {
                    if let ip = plug["ip"] as? String, let label = plug["label"] as? String {
                        if !ip.isEmpty && !label.isEmpty {
                            let idx = plug["idx"] as? String
                            let username = plug["username"] as? String
                            let password = plug["password"] as? String
                            let ipPlug = Printer.IPPlug(ip: ip, label: label, idx: idx, username: username, password: password)
                            plugs.append(ipPlug)
                        }
                    }
                }
            }
        }
        
        // Check if plugs have changed
        var update = false
        if let existing = getterPlugs(printer) {
            update = !existing.elementsEqual(plugs)
        } else {
            update = true
        }
        
        if update {
            // Update array
            setterPlugs(printer, plugs)
            // Persist updated printer
            printerManager.updatePrinter(printer)
            
            // Notify listeners of change
            for delegate in octoPrintSettingsDelegates {
                delegate.ipPlugsChanged(plugin: plugin, plugs: plugs)
            }
        }
    }

    fileprivate func calculateImageOrientation(flipH: Bool, flipV: Bool, rotate90: Bool) -> UIImage.Orientation {
        if !flipH && !flipV && !rotate90 {
             // No flips selected
            return UIImage.Orientation.up
        } else if flipH && !flipV && !rotate90 {
            // Flip webcam horizontally
            return UIImage.Orientation.upMirrored
        } else if !flipH && flipV && !rotate90 {
            // Flip webcam vertically
            return UIImage.Orientation.downMirrored
        } else if !flipH && !flipV && rotate90 {
            // Rotate webcam 90 degrees counter clockwise
            return UIImage.Orientation.left
        } else if flipH && flipV && !rotate90 {
            // Flip webcam horizontally AND Flip webcam vertically
            return UIImage.Orientation.down
        } else if flipH && !flipV && rotate90 {
            // Flip webcam horizontally AND Rotate webcam 90 degrees counter clockwise
            return UIImage.Orientation.leftMirrored
        } else if !flipH && flipV && rotate90 {
            // Flip webcam vertically AND Rotate webcam 90 degrees counter clockwise
            return UIImage.Orientation.rightMirrored
        } else {
            // Flip webcam horizontally AND Flip webcam vertically AND Rotate webcam 90 degrees counter clockwise
            return UIImage.Orientation.right
        }
    }
    
    // MARK: - Private - Printer Profile functions
    
    fileprivate func reviewPrinterProfile(printer: Printer) {
        connectionPrinterStatus { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
            if response.statusCode == 200 {
                if let json = result as? NSDictionary {
                    if let current = json["current"] as? NSDictionary {
                        if let printerProfile = current["printerProfile"] as? String {
                            self.printerProfiles(callback: { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                                if response.statusCode == 200 {
                                    if let json = result as? NSDictionary {
                                        self.updatePrinterFromPrinterProfile(printer: printer, json: json, currentProfile: printerProfile)
                                    }
                                }
                            })
                        }
                    }
                }
            }
        }
    }
    
    fileprivate func updatePrinterFromPrinterProfile(printer: Printer, json: NSDictionary, currentProfile: String) {
        var invertedX = false
        var invertedY = false
        var invertedZ = false
        
        if let profiles = json["profiles"] as? NSDictionary {
            if let currentProfile = profiles[currentProfile] as? NSDictionary {
                if let axes = currentProfile["axes"] as? NSDictionary {
                    if let xAxis = axes["x"] as? NSDictionary {
                        if let inverted = xAxis["inverted"] as? Bool {
                            invertedX = inverted
                        }
                    }
                    if let yAxis = axes["y"] as? NSDictionary {
                        if let inverted = yAxis["inverted"] as? Bool {
                            invertedY = inverted
                        }
                    }
                    if let zAxis = axes["z"] as? NSDictionary {
                        if let inverted = zAxis["inverted"] as? Bool {
                            invertedZ = inverted
                        }
                    }
                    
                    var changedX = false
                    var changedY = false
                    var changedZ = false
                    // Update camera orientation
                    if printer.invertX != invertedX {
                        printer.invertX = invertedX
                        changedX = true
                    }
                    if printer.invertY != invertedY {
                        printer.invertY = invertedY
                        changedY = true
                    }
                    if printer.invertZ != invertedZ {
                        printer.invertZ = invertedZ
                        changedZ = true
                    }
                    // Persist updated printer
                    if changedX || changedY || changedZ {
                        printerManager.updatePrinter(printer)
                    }
                    // Notify listeners of change
                    if changedX {
                        for delegate in printerProfilesDelegates {
                            delegate.axisDirectionChanged(axis: .X, inverted: invertedX)
                        }
                    }
                    if changedY {
                        for delegate in printerProfilesDelegates {
                            delegate.axisDirectionChanged(axis: .Y, inverted: invertedY)
                        }
                    }
                    if changedZ {
                        for delegate in printerProfilesDelegates {
                            delegate.axisDirectionChanged(axis: .Z, inverted: invertedZ)
                        }
                    }
                }
            }
        }
    }
    
    fileprivate func pluginCommand(plugin: String, json: NSDictionary, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let client = httpClient {
            client.post("/api/plugin/\(plugin)", json: json, expected: 204) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                callback(response.statusCode == 204, error, response)
            }
        }
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
    }
}
