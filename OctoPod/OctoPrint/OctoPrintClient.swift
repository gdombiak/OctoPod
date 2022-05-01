import Foundation
import UIKit
import CoreData

/// OctoPrint client that exposes the REST API described
/// here: http://docs.octoprint.org/en/master/api/index.html
/// A OctoPrintClient can connect to a single OctoPrint server at a time
///
/// OctoPrintClient uses websockets for getting realtime updates from OctoPrint (read operations only)
/// and an HTTP Client is used for requesting services on the OctoPrint server.
class OctoPrintClient: WebSocketClientDelegate, AppConfigurationDelegate {
        
    var octoPrintRESTClient: OctoPrintRESTClient!
    
    var printerManager: PrinterManager!
    var webSocketClient: WebSocketClient?
    
    let terminal = Terminal()
    let tempHistory = TempHistory()
    let socTempHistory = SoCTempHistory()

    var delegates: Array<OctoPrintClientDelegate> = Array()
    var octoPrintSettingsDelegates: Array<OctoPrintSettingsDelegate> = Array()
    var printerProfilesDelegates: Array<PrinterProfilesDelegate> = Array()
    var octoPrintPluginsDelegates: Array<OctoPrintPluginsDelegate> = Array()
    
    var appConfiguration: AppConfiguration?

    // Remember last CurrentStateEvent that was reported from OctoPrint (via websockets)
    var lastKnownState: CurrentStateEvent?
    var octoPrintVersion: String?
    private var printerID: NSManagedObjectID?
    
    init(printerManager: PrinterManager, appConfiguration: AppConfiguration) {
        self.printerManager = printerManager
        self.octoPrintRESTClient = OctoPrintRESTClient()

        self.appConfiguration = appConfiguration
        // Listen to configuration changes
        self.appConfiguration?.delegates.append(self)
        // Add AppConfiguration as a listener of this OctoPrintClient
        delegates.append(appConfiguration)

        #if os(iOS)
            // Configure REST client to show network activity in iOS app when making requests
            self.octoPrintRESTClient.preRequest = {
                DispatchQueue.main.async(execute: { () -> Void in UIApplication.shared.isNetworkActivityIndicatorVisible = true })
            }
            self.octoPrintRESTClient.postRequest = {
                DispatchQueue.main.async(execute: { () -> Void in UIApplication.shared.isNetworkActivityIndicatorVisible = false })
            }
        #endif
    }
    
    // MARK: - OctoPrint server connection
    
    /// Connect to OctoPrint server and gather printer state
    /// A websocket connection will be attempted to get real time updates from OctoPrint
    /// An HTTPClient is created for sending requests to OctoPrint
    func connectToServer(printer: Printer) {
        // Clean up any known printer state
        lastKnownState = nil
        
        // Remember printer we are connected to
        printerID = printer.objectID
        
        // Create and keep httpClient while default printer does not change
        octoPrintRESTClient.connectToServer(serverURL: printer.hostname, apiKey: printer.apiKey, username: printer.username, password: printer.password, preemptive: printer.preemptiveAuthentication())
        
        if webSocketClient?.isConnected(printer: printer) == true {
            // Do nothing since we are already connected to the default printer
            return
        }
        
        for delegate in delegates {
            delegate.notificationAboutToConnectToServer()
        }
        
        // Clean up any temp history
        tempHistory.clear()
        socTempHistory.clear()
        
        // We need to rediscover the version of OctoPrint so clean up old values
        octoPrintVersion = nil
        
        // Close any previous connection
        webSocketClient?.closeConnection()
        
        // Notify the terminal that we are about to connect to OctoPrint
        terminal.websocketNewConnection()
        // Create websocket connection and connect
        webSocketClient = WebSocketClient(appConfiguration: appConfiguration!, printer: printer)
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
                        event!.parseTemps(temp: temp, sharedNozzle: printer.sharedNozzle)
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
                if let event = event {
                    self.lastKnownState = event
                    // Notify that we received new status information from OctoPrint
                    self.currentStateUpdated(event: event)
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
        
        // Discover OctoPrint version
        octoPrintRESTClient.versionInformation { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
            if let json = result as? NSDictionary {
                if let server = json["server"] as? String {
                    self.octoPrintVersion = server
                }
            }
        }
        
        // Retrieve history of System on a chip (SoC) temperatures from OctoPod plugin (if installed)
        // We can now track RPi temperatures
        octoPrintRESTClient.getSoCTemperatures { (result: Array<SoCTempHistory.Temp>?, error: Error?, response: HTTPURLResponse) in
            if let history = result {
                self.socTempHistory.addHistory(history: history)
                // Notify other listeners that history of temperature state has changed
                for delegate in self.delegates {
                    delegate.tempHistoryChanged()
                }
            }
        }
    }
    
    /// Disconnect from OctoPrint server
    func disconnectFromServer() {
        octoPrintRESTClient.disconnectFromServer()
        webSocketClient?.closeConnection()
        webSocketClient = nil
    }
    
    fileprivate func isConnectionError(error: Error?, response: HTTPURLResponse) -> Bool {
        if let _ = error as NSError? {
            return true
        } else if response.statusCode == 403 {
            return true
        } else if response.statusCode >= 600 &&  response.statusCode <= 605 {
            // These are OctoEverywhere special error codes
            // See https://octoeverywhere.stoplight.io/docs/octoeverywhere-api-docs/docs/App-Connection-Usage.md
            return true
        } else {
            // Return that there were no errors
            return false
        }
    }

    // MARK: - WebSocketClientDelegate
    
    func currentStateUpdated(event: CurrentStateEvent) {
        // Track event as last known state. Will be reset when changing printers or on app cold startup
        lastKnownState = event
        // Notify the terminal that OctoPrint and/or Printer state has changed
        terminal.currentStateUpdated(event: event)
        // Track temp history
        if event.bedTempActual != nil || event.tool0TempActual != nil || event.tool1TempActual != nil || event.tool2TempActual != nil || event.tool3TempActual != nil || event.tool4TempActual != nil {
            var temp = TempHistory.Temp()
            temp.parseTemps(event: event)
            tempHistory.addTemp(temp: temp)
        }
        // Notify other listeners that OctoPrint and/or Printer state has changed
        for delegate in delegates {
            delegate.printerStateUpdated(event: event)
        }
    }
    
    func historyTemp(history: Array<TempHistory.Temp>) {
        tempHistory.addHistory(history: history)
        // Notify other listeners that history of temperature state has changed
        for delegate in self.delegates {
            delegate.tempHistoryChanged()
        }
    }
    
    func octoPrintSettingsUpdated() {
        if let id = printerID, let idURL = URL(string: id.uriRepresentation().absoluteString), let printer = printerManager.getPrinterByObjectURL(url: idURL) {
            // Verify that last known settings are still current
            reviewOctoPrintSettings(printer: printer)
        }
    }
    
    func printerProfileUpdated() {
        if let id = printerID, let idURL = URL(string: id.uriRepresentation().absoluteString), let printer = printerManager.getPrinterByObjectURL(url: idURL) {
            // Update Printer from /api/printerprofiles information
            reviewPrinterProfile(printer: printer)
        }
    }
    
    func pluginMessage(plugin: String, data: NSDictionary) {
        // Special case for tracking SoC temperatures reported by OctoPod plugin
        if plugin == Plugins.OCTOPOD {
            if let _ = data["temp"] as? Double, let _ = data["time"] as? Int {
                var temp = SoCTempHistory.Temp()
                temp.parseTemps(data: data)
                socTempHistory.addTemp(temp: temp)
            }
        }
        // Notify other listeners that we connected to OctoPrint
        for delegate in octoPrintPluginsDelegates {
            delegate.pluginMessage(plugin: plugin, data: data)
        }
    }

    func websocketConnected() {
        // Websocket has been established. OctoPrint 1.3.10, by default, secures websocket so we need
        // to authenticate the websocket in order to be able to use it. In order to authenticate the websocket,
        // we need to execute a passive login that will return the user_id and session. This information is then
        // passed back via websockets to OctoPrint.
        passiveLogin { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
            if let result = result as? NSDictionary {
                if let name = result["name"] as? String, let session = result["session"] as? String {
                    // OctoPrint requires authentication of websocket.
                    self.webSocketClient?.authenticate(user: name, session: session)
                }
            }
            
            // Notify the terminal that we connected to OctoPrint
            self.terminal.websocketConnected()
            // Notify other listeners that we connected to OctoPrint
            for delegate in self.delegates {
                delegate.websocketConnected()
            }
        }
    }
    
    func websocketConnectionFailed(error: Error) {
        for delegate in delegates {
            delegate.websocketConnectionFailed(error: error)
        }
    }
    
    // MARK: - AppConfigurationDelegate
    
    /// Notification that SSL certificate validation has changed (user enabled or disabled it)
    func certValidationChanged(disabled: Bool) {
        // Recreate websocket connection since SSL cert validation has changed
        // HTTP connection relies on NSAllowsArbitraryLoads so will ignore this change/setting
        disconnectFromServer()
        if let id = printerID, let idURL = URL(string: id.uriRepresentation().absoluteString), let printer = printerManager.getPrinterByObjectURL(url: idURL) {
            connectToServer(printer: printer)
        }
    }

    // MARK: - OctoPrint version
    
    func isEqualOrNewerThan(major: Int, minor: Int, patch: Int) -> Bool? {
        if let version = octoPrintVersion {
            // Future optimization if needed is to parse regex once and store parsed values
            // when OctoPrint version is discovered
            let pattern = "([\\d]+).([\\d]+).([\\d]+)"
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])

                if let match = regex.firstMatch(in: version, options: [], range: NSMakeRange(0, version.utf16.count)) {
                    let opMajor = Int((version as NSString).substring(with: match.range(at: 1)))!
                    let opMinor = Int((version as NSString).substring(with: match.range(at: 2)))!
                    let opPatch = Int((version as NSString).substring(with: match.range(at: 3)))!
                    
                    let currentVersion = [opMajor, opMinor, opPatch]
                    let requiredVersion = [major, minor, patch]
                    
                    for (index, part) in currentVersion.enumerated() {
                        if part != requiredVersion[index] {
                            return part > requiredVersion[index]
                        }
                    }
                    return true
                }
            }
            catch {
                NSLog("Error testing regex while comparing OctoPrint version. Error: \(error)")
            }
        }
        NSLog("Unknown OctoPrint version while comparing OctoPrint version")
        return nil
    }
    
    // MARK: - Login operations

    /// Passive login has been added to OctoPrint 1.3.10 to increase security. Endpoint existed before
    /// but without passive mode. New version returns a "session" field that is used by websockets to
    /// allow websockets to work when Forcelogin Plugin is active (the default)
    func passiveLogin(callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.passiveLogin(callback: callback)
    }

    /// Probes for application key workflow support
    /// - parameters:
    ///     - callback: success; error; http response
    ///     - success: true if application key is supported/enabled
    ///     - error: any error that happened making the HTTP request
    ///     - response: HTTP response
    func appkeyProbe(callback: @escaping (_ success: Bool, _ error: Error?, _ response: HTTPURLResponse) -> Void) {
        octoPrintRESTClient.appkeyProbe(callback: callback)
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
        octoPrintRESTClient.appkeyRequest(app: app, callback: callback)
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
        octoPrintRESTClient.appkeyPoll(location: location, callback: callback)
    }

    // MARK: - Connection operations

    /// Return connection status from OctoPrint to the 3D printer
    func connectionPrinterStatus(callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.connectionPrinterStatus(callback: callback)
    }
    
    /// Ask OctoPrint to connect using default settings. We always get 204 status code (unless there was some network error)
    /// To know if OctoPrint was able to connect to the 3D printer then we need to check for its connection status
    func connectToPrinter(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.connectToPrinter(callback: callback)
    }

    /// Ask OctoPrint to disconnect from the 3D printer. Use connection status to check if it was successful
    func disconnectFromPrinter(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.disconnectFromPrinter(callback: callback)
    }
    
    // MARK: - Job operations

    func currentJobInfo(callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.currentJobInfo(callback: callback)
    }
    
    func pauseCurrentJob(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.pauseCurrentJob(callback: callback)
    }

    func resumeCurrentJob(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.resumeCurrentJob(callback: callback)
    }
    
    func cancelCurrentJob(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.cancelCurrentJob(callback: callback)
    }
    
    // There needs to be an active job that has been paused in order to be able to restart
    func restartCurrentJob(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.restartCurrentJob(callback: callback)
    }
    
    // MARK: - Printer operations
    
    /// Retrieves the current state of the printer. Returned information includes:
    /// 1. temperature information (see also Retrieve the current tool state and Retrieve the current bed state)
    /// 2. sd state (if available, see also Retrieve the current SD state)
    /// 3. general printer state
    func printerState(callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.printerState(callback: callback)
    }
    
    func bedTargetTemperature(newTarget: Int, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.bedTargetTemperature(newTarget: newTarget, callback: callback)
    }

    func toolTargetTemperature(toolNumber: Int, newTarget: Int, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.toolTargetTemperature(toolNumber: toolNumber, newTarget: newTarget, callback: callback)
    }
    
    /**
     Sets target temperature for the printer’s heated chamber
     - Parameter newTarget: new chamber temperature to set
     - Parameter callback: callback to execute after HTTP request is done
     */
    func chamberTargetTemperature(newTarget: Int, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.chamberTargetTemperature(newTarget: newTarget, callback: callback)
    }

    /// Set the new flow rate for the requested extruder. Currently there is no way to read current flow rate value
    func toolFlowRate(toolNumber: Int, newFlowRate: Int, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.toolFlowRate(toolNumber: toolNumber, newFlowRate: newFlowRate, callback: callback)
    }
    
    func extrude(toolNumber: Int, delta: Int, speed: Int?, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.extrude(toolNumber: toolNumber, delta: delta, speed: speed, callback: callback)
    }
    
    func sendCommand(gcode: String, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.sendCommand(gcode: gcode, callback: callback)
    }
    
    // MARK: - Print head operations (move operations)
    
    func home(axes: Array<String>, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.home(axes: axes, callback: callback)
    }
    
    func move(x delta: Float, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.move(x: delta, callback: callback)
    }
    
    func move(y delta: Float, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.move(y: delta, callback: callback)
    }
    
    func move(z delta: Float, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.move(z: delta, callback: callback)
    }
    
    // Set the feed rate factor using an integer argument
    func feedRate(factor: Int, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.feedRate(factor: factor, callback: callback)
    }
    
    // MARK: - File operations
    
    /// Returns list of existing files
    func files(folder: PrintFile? = nil, recursive: Bool = true, callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        let location = folder == nil ? "" : "/\(folder!.origin!)/\(folder!.path!)"
        octoPrintRESTClient.files(location: location, recursive: recursive, callback: callback)
    }
    
    /// Deletes the specified file
    func deleteFile(origin: String, path: String, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.deleteFile(origin: origin, path: path, callback: callback)
    }
    
    /// Prints the specified file
    func printFile(origin: String, path: String, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.printFile(origin: origin, path: path, callback: callback)
    }
    
    /// Uploads file to the specified location in OctoPrint's local file system
    /// If no folder is specified then file will be uploaded to root folder in OctoPrint
    func uploadFileToOctoPrint(folder: PrintFile? = nil, filename: String, fileContent: Data , callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        let path: String? = folder == nil ? nil : folder!.path!
        octoPrintRESTClient.uploadFileToOctoPrint(path: path, filename: filename, fileContent: fileContent, callback: callback)
    }
    
    /// Uploads file to the SD Card (OctoPrint will first upload to OctoPrint and then copy to SD Card so we will end up with a copy in OctoPrint as well)
    func uploadFileToSDCard(filename: String, fileContent: Data , callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.uploadFileToSDCard(filename: filename, fileContent: fileContent, callback: callback)
    }

    // MARK: - SD Card operations

    /// Initialize the SD Card. Files will be read from the SD card during this operation
    func initSD(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.initSD(callback: callback)
    }

    /// Read files from the SD card during this operation. You will need to call #files() when this operation was run successfully
    func refreshSD(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.refreshSD(callback: callback)
    }
    
    /// Release the SD card from the printer. The reverse operation to initSD()
    func releaseSD(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.releaseSD(callback: callback)
    }

    // MARK: - Fan operations
    
    /// Set the new fan speed. We receive a value between 0 and 100 and need to convert to rante 0-255
    /// There is no way to read current fan speed
    func fanSpeed(speed: Int, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.fanSpeed(speed: speed, callback: callback)
    }

    // MARK: - Motor operations
    
    func disableMotor(axis: axis, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.disableMotor(axis: axis, callback: callback)
    }
    
    // MARK: - Settings operations
    
    func octoPrintSettings(callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.octoPrintSettings(callback: callback)
    }
    
    // MARK: - Printer Profile operations
    
    func printerProfiles(callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.printerProfiles(callback: callback)
    }
    
    // MARK: - System Commands operations
    
    func systemCommands(callback: @escaping (Array<SystemCommand>?, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.systemCommands(callback: callback)
    }
    
    func executeSystemCommand(command: SystemCommand, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.executeSystemCommand(command: command, callback: callback)
    }

    // MARK: - Timelapse operations
    
    /// Retrieve a list of timelapses
    func timelapses(callback: @escaping (Array<Timelapse>?, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.timelapses(callback: callback)
    }

    /// Delete the specified timelapse
    /// - Parameters:
    ///     - timelapse: Timelapse to delete
    ///     - callback: callback to execute after HTTP request is done
    func deleteTimelapse(timelapse: Timelapse, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.deleteTimelapse(timelapse: timelapse, callback: callback)
    }
    
    /// Download specified timelapse file
    /// - Parameters:
    ///     - timelapse: Timelapse to delete
    ///     - progress: callback to execute while download is in progress
    ///     - completion: callback to execute after download is done
    func downloadTimelapse(timelapse: Timelapse, progress: @escaping (Int64, Int64) -> Void, completion: @escaping (Data?, Error?) -> Void) {
        octoPrintRESTClient.downloadTimelapse(timelapse: timelapse, progress: progress, completion: completion)
    }
    
    // MARK: - Custom Controls operations

    func customControls(callback: @escaping (Array<Container>?, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.customControls(callback: callback)
    }
    
    func executeCustomControl(control: NSDictionary, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
       octoPrintRESTClient.executeCustomControl(control: control, callback: callback)
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
        octoPrintRESTClient.checkPluginUpdates(callback: callback)
    }
    
    // MARK: - PSU Control Plugin operations
    
    func turnPSU(on: Bool, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.turnPSU(on: on, callback: callback)
    }
    
    func getPSUState(callback: @escaping (Bool?, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.getPSUState(callback: callback)
    }

    // MARK: - IP Plug Plugin (TPLink Smartplug, Wemo, Domoticz, etc.)
    
    /// Instruct an IP plugin (e.g. TPLinkSmartplug, WemoSwitch, domoticz) to turn on/off the
    /// device with the specified IP address. If request was successful we get back a 204
    /// and the status is reported via websockets
    func turnIPPlug(plugin: String, on: Bool, plug: IPPlug, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.turnIPPlug(plugin: plugin, on: on, plug: plug, callback: callback)
    }
    
    /// Instruct an IP plugin (e.g. TPLinkSmartplug, WemoSwitch, domoticz) to turn on/off the
    /// device with the specified IP address. If request was successful we get back a 204
    /// and the status is reported via websockets
    func turnIPPlug(plugin: String, on: Bool, plug: IPPlug, callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.turnIPPlug(plugin: plugin, on: on, plug: plug, callback: callback)
    }
    
    /// Instruct an IP plugin to report the status of the device with the specified IP address
    /// If request was successful we get back a 204 and the status is reported via websockets
    func checkIPPlugStatus(plugin: String, plug: IPPlug, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.checkIPPlugStatus(plugin: plugin, plug: plug, callback: callback)
    }
    
    /// Instruct an IP plugin to report the status of the device with the specified IP address
    /// If request was successful we get back a 204 and the status is reported via websockets
    func checkIPPlugStatus(plugin: String, plug: IPPlug, callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.checkIPPlugStatus(plugin: plugin, plug: plug, callback: callback)
    }
    
    // MARK: - Cancel Object Plugin operations
    
    /// Get list of objects that are part of the current gcode being printed. Objects already cancelled will be part of the response
    func getCancelObjects(callback: @escaping (Array<CancelObject>?, Error?, HTTPURLResponse) -> Void) {
        if let id = printerID, let idURL = URL(string: id.uriRepresentation().absoluteString), let printer = printerManager.getPrinterByObjectURL(url: idURL) {
            let ignore = CancelObject.parseCancelObjectIgnore(ignored: printer.cancelObjectIgnored)
            octoPrintRESTClient.getCancelObjects(ignore: ignore, callback: callback)
        }
    }
    
    /// Cancel the requested object id.
    func cancelObject(id: Int, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.cancelObject(id: id, callback: callback)
    }
    
    // MARK: - Octorelay Plugin operations
    
    /// Get list of relays including their names and active status
    func getOctorelays(callback: @escaping (Array<Octorelay>?, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.getOctorelay(callback: callback)
    }
    
    /// Switch (i.e. flip) relay status
    func switchRelay(id: String, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.switchRelay(id: id, callback: callback)
    }
    
    // MARK: - OctoPod Plugin operations
    
    /**
     Register new APNS token so app can receive push notifications from OctoPod plugin
     */
    func registerAPNSToken(oldToken: String?, newToken: String, deviceName: String, printerID: String, printerName: String, languageCode: String, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.registerAPNSToken(oldToken: oldToken, newToken: newToken, deviceName: deviceName, printerID: printerID, printerName: printerName, languageCode: languageCode, callback: callback)
    }

    /**
     Register new APNS token so app can receive push notifications from OctoPod plugin
     - Parameter eventCode: code that identifies event that we want to snooze (eg. mmu-event)
     - Parameter minutes: number of minutes to snooze
     - Parameter callback: callback to execute when HTTP request is done
     */
    func snoozeAPNSEvents(eventCode: String, minutes: Int, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.snoozeAPNSEvents(eventCode: eventCode, minutes: minutes, callback: callback)
    }
    
    /// Adds or removes notification for specified layer. DisplayLayerProgress and OctoPod plugins are required
    /// - parameters:
    ///     - layer: number of layer to be notified
    ///     - add: Add or Delete notification for the specified layer
    ///     - callback: callback to execute when HTTP request is done
    func layerNotification(layer: String, add: Bool, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.layerNotification(layer: layer, add: add, callback: callback)
    }

    /// Returns layers for which a push notification will be sent. DisplayLayerProgress and OctoPod plugins are required
    ///
    /// - parameters:
    ///     - callback: callback to execute when HTTP request is done
    func getLayerNotifications(callback: @escaping (Array<String>?, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.getLayerNotifications(callback: callback)
    }
    
    // MARK: - Palette 2 Plugin
    
    /// Request Palette 2 plugin to send its status via websockets. If request was successful we get back a 200
    /// and status is reported via websockets
    /// - parameter callback: callback to execute when HTTP request is done
    func palette2Status(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.palette2Status(plugin: Plugins.PALETTE_2, callback: callback)
    }

    /// Request Palette 2 plugin to send list of available ports via websockets. These are the ports available on
    /// the server where OctoPrint runs so that Palette 2 can connect. If request was successful we get back a 200
    /// and status is reported via websockets
    /// - parameter callback: callback to execute when HTTP request is done
    func palette2Ports(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.palette2Ports(plugin: Plugins.PALETTE_2, callback: callback)
    }
    
    /// Request Palette 2 plugin to connect to Palette device. If request was successful we get back a 200
    /// and status is reported via websockets
    /// - parameter port: Port that Palette device is connected to on the OctoPrint server
    /// - parameter callback: callback to execute when HTTP request is done
    func palette2Connect(port: String?, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.palette2Connect(plugin: Plugins.PALETTE_2, port: port, callback: callback)
    }

    /// Request Palette 2 plugin to disconnect from Palette device. If request was successful we get back a 200
    /// and status is reported via websockets
    /// - parameter callback: callback to execute when HTTP request is done
    func palette2Disconnect(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.palette2Disconnect(plugin: Plugins.PALETTE_2, callback: callback)
    }
    
    /// Request Palette 2 plugin to tell Palette device to start printing. If request was successful we
    /// get back a 200
    /// - parameter callback: callback to execute when HTTP request is done
    func palette2Print(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.palette2Print(plugin: Plugins.PALETTE_2, callback: callback)
    }
    
    /// Request Palette 2 plugin to tell Palette device to perform a cut. If request was successful we
    /// get back a 200
    /// - parameter callback: callback to execute when HTTP request is done
    func palette2Cut(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.palette2Cut(plugin: Plugins.PALETTE_2, callback: callback)
    }
    
    /// Request Palette 2 plugin to tell Palette device to perform a clear. If request was successful we
    /// get back a 200
    /// - parameter callback: callback to execute when HTTP request is done
    func palette2Clear(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.palette2Clear(plugin: Plugins.PALETTE_2, callback: callback)
    }
    
    // MARK: - Enclosure Plugin
    
    /// Request enclosure plugin to refresh UI. This will cause plugin to send values for input and output elements
    func refreshEnclosureStatus(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.refreshEnclosureStatus(callback: callback)
    }
    
    /// Returns the queried GPIO value for the specified GPIO output
    func getEnclosureGPIOStatus(index_id: Int16, callback: @escaping (Bool?, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.getEnclosureGPIOStatus(index_id: index_id, callback: callback)
    }
    
    /// Change status of GPIO pin via Enclosure plugin
    func changeEnclosureGPIO(index_id: Int16, status: Bool, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.changeEnclosureGPIO(index_id: index_id, status: status, callback: callback)
    }

    /// Change PWM value via Enclosure plugin
    func changeEnclosurePWM(index_id: Int16, dutyCycle: Int, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.changeEnclosurePWM(index_id: index_id, dutyCycle: dutyCycle, callback: callback)
    }
    
    /// Change temperature or humidity control value via Enclosure plugin
    func changeEnclosureTempControl(index_id: Int16, temp: Int, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.changeEnclosureTempControl(index_id: index_id, temp: temp, callback: callback)
    }

    // MARK: - PrusaSlicer Thumbnails & Ultimaker Format Package Plugins
    
    /// Returns content of thumbnail image. This informatin is only available when PrusaSlicer was configured properly
    /// and PrusaSlicer Thumbnails plugin is installed
    func getThumbnailImage(path: String, callback: @escaping (Data?, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.getThumbnailImage(path: path, callback: callback)
    }
    
    // MARK: - FilamentManager Plugin
    
    /// Returns current filament selection for each extruder
    func filamentSelections(callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.filamentSelections(callback: callback)
    }

    /// Returns configured filament spools. Answer also includes profile information (vendor and filament type)
    func filamentSpools(callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.filamentSpools(callback: callback)
    }
    
    /// Changes filament selected for specified extruder
    func changeFilamentSelection(toolNumber: Int, spoolId: Int, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.changeFilamentSelection(toolNumber: toolNumber, spoolId: spoolId, callback: callback)
    }
    
    // MARK: - DisplayLayerProgress Plugin
    
    /// Ask DisplayLayerProgress to send latest status via websockets
    func refreshDisplayLayerProgress(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.refreshDisplayLayerProgress(callback: callback)
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

    
    // MARK: - Private - Settings functions
    
    fileprivate func reviewOctoPrintSettings(printer: Printer) {
        // Update Printer from /api/settings information
        octoPrintSettings { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
            if response.statusCode == 200 {
                if let json = result as? NSDictionary {
                    self.updatePrinterFromSettings(printer: printer, json: json)
                    // if DisplayLayerProgress plugin is installed then request latest info
                    // (Otherwise info is not sent until there is a layer/height change)
                    if let plugins = json["plugins"] as? NSDictionary, let _ = plugins["DisplayLayerProgress"] as? NSDictionary {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.refreshDisplayLayerProgress { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                                if !requested && response.statusCode != 404 {
                                    NSLog("Error refreshing DisplayLayerProgress status. Error: \(response). Response: \(response)")
                                }
                            }
                        }
                    }
                }
            }
        }
        // Update Printer from /api/printerprofiles information
        reviewPrinterProfile(printer: printer)
    }
    
    fileprivate func updatePrinterFromSettings(printer: Printer, json: NSDictionary) {
        let newObjectContext = printerManager.newPrivateContext()
        let printerToUpdate = newObjectContext.object(with: printer.objectID) as! Printer

        if let feature = json["feature"] as? NSDictionary {
            if let sdSupport = feature["sdSupport"] as? Bool {
                if printer.sdSupport != sdSupport {
                    // Update sd support
                    printerToUpdate.sdSupport = sdSupport
                    // Persist updated printer
                    printerManager.updatePrinter(printerToUpdate, context: newObjectContext)

                    // Notify listeners of change
                    for delegate in octoPrintSettingsDelegates {
                        delegate.sdSupportChanged(sdSupport: sdSupport)
                    }
                }
            }
        }

        if let temperature = json["temperature"] as? NSDictionary {
            if let profiles = temperature["profiles"] as? NSArray {
                var bedTemps: Array<Int> = []
                var extruderTemps: Array<Int> = []
                for case let profile as NSDictionary in profiles {
                    if let bedTemp = profile["bed"] as? Int {
                        bedTemps.append(bedTemp)
                    }
                    if let extruderTemp = profile["extruder"] as? Int {
                        extruderTemps.append(extruderTemp)
                    }
                }
                bedTemps = bedTemps.sorted()
                extruderTemps = extruderTemps.sorted()
                if printerToUpdate.bedTemps != bedTemps || printerToUpdate.extruderTemps != extruderTemps {
                    // Update profile temps from settings
                    printerToUpdate.bedTemps = bedTemps
                    printerToUpdate.extruderTemps = extruderTemps
                    // Persist updated printer
                    printerManager.updatePrinter(printerToUpdate, context: newObjectContext)
                }
            }
        }
        
        if let webcam = json["webcam"] as? NSDictionary {
            if let flipH = webcam["flipH"] as? Bool, let flipV = webcam["flipV"] as? Bool, let rotate90 = webcam["rotate90"] as? Bool {
                let newOrientation = calculateImageOrientation(flipH: flipH, flipV: flipV, rotate90: rotate90)
                if printer.cameraOrientation != Int16(newOrientation.rawValue) {
                    // Update camera orientation
                    printerToUpdate.cameraOrientation = Int16(newOrientation.rawValue)
                    // Persist updated printer
                    printerManager.updatePrinter(printerToUpdate, context: newObjectContext)

                    // Notify listeners of change
                    for delegate in octoPrintSettingsDelegates {
                        delegate.cameraOrientationChanged(newOrientation: newOrientation)
                    }
                }
            }
            if let streamUrl = webcam["streamUrl"] as? String {
                if printer.streamUrl != streamUrl {
                    // Update path to camera hosted by OctoPrint
                    printerToUpdate.streamUrl = streamUrl
                    // Persist updated printer
                    printerManager.updatePrinter(printerToUpdate, context: newObjectContext)

                    // Notify listeners of change
                    for delegate in octoPrintSettingsDelegates {
                        delegate.cameraPathChanged(streamUrl: streamUrl)
                    }
                }
            }
        }
        
        if let appearance = json["appearance"] as? NSDictionary {
            if let color = appearance["color"] as? String {
                if printer.color != color {
                    // Update printer with OctoPrint's appearance configuration
                    printerToUpdate.color = color
                    // Persist updated printer
                    printerManager.updatePrinter(printerToUpdate, context: newObjectContext)
                    
                    // Notify listeners of change
                    for delegate in octoPrintSettingsDelegates {
                        delegate.octoPrintColorChanged(color: color)
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
        updatePrinterFromOctorelayPlugin(printer: printer, plugins: plugins)
        updatePrinterFromTasmotaPlugin(printer: printer, plugins: plugins)
        updatePrinterFromCancelObjectPlugin(printer: printer, plugins: plugins)
        updatePrinterFromOctoPodPlugin(printer: printer, plugins: plugins)
        updatePrinterFromPalette2Plugin(printer: printer, plugins: plugins)
        updatePrinterFromPalette2CanvasPlugin(printer: printer, plugins: plugins)
        updatePrinterFromEnclosurePlugin(printer: printer, plugins: plugins)
        updatePrinterFromFilamentManagerPlugin(printer: printer, plugins: plugins)
        updatePrinterFromBLTouchPlugin(printer: printer, plugins: plugins)
    }
    
    fileprivate func updatePrinterFromMultiCamPlugin(printer: Printer, plugins: NSDictionary) {
        // Check if MultiCam plugin is installed. If so then copy cameras information
        var camerasURLs: Array<String> = Array()
        var count: Int16 = 0
        var camerasChanged = false
        if let multicam = plugins[Plugins.MULTICAM] as? NSDictionary {
            if let profiles = multicam["multicam_profiles"] as? NSArray {
                for case let profile as NSDictionary in profiles {
                    count += 1
                    if let url = profile["URL"] as? String, let flipH = profile["flipH"] as? Bool, let flipV = profile["flipV"] as? Bool, let rotate90 = profile["rotate90"] as? Bool, let name = profile["name"] as? String, let streamRatio = profile["streamRatio"] as? String {
                        let newOrientation = calculateImageOrientation(flipH: flipH, flipV: flipV, rotate90: rotate90)
                        var found = false
                        if let existingCameras = printer.multiCameras {
                            for existingCamera in existingCameras {
                                if existingCamera.index_id == count {
                                    found = true
                                    // Check that values are current
                                    if existingCamera.name != name || existingCamera.cameraURL != url || existingCamera.cameraOrientation != Int16(newOrientation.rawValue) || existingCamera.streamRatio != streamRatio {
                                        // Update existing input
                                        let newObjectContext = printerManager.newPrivateContext()
                                        let cameraToUpdate = newObjectContext.object(with: existingCamera.objectID) as! MultiCamera
                                        cameraToUpdate.name = name
                                        cameraToUpdate.cameraURL = url
                                        cameraToUpdate.cameraOrientation = Int16(newOrientation.rawValue)
                                        cameraToUpdate.streamRatio = streamRatio
                                        // Persist updated MultiCamera
                                        printerManager.saveObject(cameraToUpdate, context: newObjectContext)
                                        
                                        camerasChanged = true
                                    }
                                    break
                                }
                            }
                        }
                        if !found {
                            // Add new camera
                            let newObjectContext = printerManager.newPrivateContext()
                            let printerToUpdate = newObjectContext.object(with: printer.objectID) as! Printer
                            printerManager.addMultiCamera(index: count, name: name, cameraURL: url, cameraOrientation: Int16(newOrientation.rawValue), streamRatio: streamRatio, context: newObjectContext, printer: printerToUpdate)
                            camerasChanged = true
                        }
                        camerasURLs.append(url)
                    }
                }
            }
        }
        // Delete existing cameras that no longer exist
        if let existingCameras = printer.multiCameras {
            for existingCamera in existingCameras {
                if existingCamera.index_id > count {
                    // Delete camera that no longer exists on the server
                    let newObjectContext = printerManager.newPrivateContext()
                    let cameraToDelete = newObjectContext.object(with: existingCamera.objectID) as! MultiCamera
                    printerManager.deleteObject(cameraToDelete, context: newObjectContext)
                    camerasChanged = true
                }
            }
        }

        if camerasChanged {
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
            let newObjectContext = printerManager.newPrivateContext()
            let printerToUpdate = newObjectContext.object(with: printer.objectID) as! Printer
            // Update flag that tracks if PSU Control plugin is installed
            printerToUpdate.psuControlInstalled = installed
            // Persist updated printer
            printerManager.updatePrinter(printerToUpdate, context: newObjectContext)

            // Notify listeners of change
            for delegate in octoPrintSettingsDelegates {
                delegate.psuControlAvailabilityChanged(installed: installed)
            }
        }
    }
    
    fileprivate func updatePrinterFromTPLinkSmartplugPlugin(printer: Printer, plugins: NSDictionary) {
        // Check if TPLinkSmartplug plugin is installed. If so then copy plugs information so there is
        // no need to reenter this information
        updatePrinterFromIPPlugPlugin(printer: printer, plugins: plugins, plugin: Plugins.TP_LINK_SMARTPLUG, getterPlugs: { (printer: Printer) -> Array<IPPlug>? in
            return printer.getTPLinkSmartplugs()
        }) { (printer: Printer, plugs: Array<IPPlug>) in
            printer.setTPLinkSmartplugs(plugs: plugs)
        }
    }
    
    fileprivate func updatePrinterFromWemoPlugin(printer: Printer, plugins: NSDictionary) {
        // Check if Wemo plugin is installed. If so then copy plugs information so there is
        // no need to reenter this information
        updatePrinterFromIPPlugPlugin(printer: printer, plugins: plugins, plugin: Plugins.WEMO_SWITCH, getterPlugs: { (printer: Printer) -> Array<IPPlug>? in
            return printer.getWemoPlugs()
        }) { (printer: Printer, plugs: Array<IPPlug>) in
            printer.setWemoPlugs(plugs: plugs)
        }

    }
    
    fileprivate func updatePrinterFromDomoticzPlugin(printer: Printer, plugins: NSDictionary) {
        // Check if Domoticz plugin is installed. If so then copy plugs information so there is
        // no need to reenter this information
        updatePrinterFromIPPlugPlugin(printer: printer, plugins: plugins, plugin: Plugins.DOMOTICZ, getterPlugs: { (printer: Printer) -> Array<IPPlug>? in
            return printer.getDomoticzPlugs()
        }) { (printer: Printer, plugs: Array<IPPlug>) in
            printer.setDomoticzPlugs(plugs: plugs)
        }
    }
    
    fileprivate func updatePrinterFromTasmotaPlugin(printer: Printer, plugins: NSDictionary) {
        // Check if Tasmota plugin is installed. If so then copy plugs information so there is
        // no need to reenter this information
        updatePrinterFromIPPlugPlugin(printer: printer, plugins: plugins, plugin: Plugins.TASMOTA, getterPlugs: { (printer: Printer) -> Array<IPPlug>? in
            return printer.getTasmotaPlugs()
        }) { (printer: Printer, plugs: Array<IPPlug>) in
            printer.setTasmotaPlugs(plugs: plugs)
        }
    }
    
    fileprivate func updatePrinterFromIPPlugPlugin(printer: Printer, plugins: NSDictionary, plugin: String, getterPlugs: ((Printer) ->  Array<IPPlug>?), setterPlugs: ((Printer, Array<IPPlug>) -> Void)) {
        // Check if TPLinkSmartplug plugin is installed. If so then copy plugs information so there is
        // no need to reenter this information
        var plugs: Array<IPPlug> = []
        if let tplinksmartplug = plugins[plugin] as? NSDictionary {
            if let arrSmartplugs = tplinksmartplug["arrSmartplugs"] as? NSArray {
                for case let plug as NSDictionary in arrSmartplugs {
                    if let ip = plug["ip"] as? String, let label = plug["label"] as? String {
                        if !ip.isEmpty && !label.isEmpty {
                            let idx = plug["idx"] as? String
                            let username = plug["username"] as? String
                            let password = plug["password"] as? String
                            let ipPlug = IPPlug(ip: ip, label: label, idx: idx, username: username, password: password)
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
            let newObjectContext = printerManager.newPrivateContext()
            let printerToUpdate = newObjectContext.object(with: printer.objectID) as! Printer
            // Update array
            setterPlugs(printerToUpdate, plugs)
            // Persist updated printer
            printerManager.updatePrinter(printerToUpdate, context: newObjectContext)
            
            // Notify listeners of change
            for delegate in octoPrintSettingsDelegates {
                delegate.ipPlugsChanged(plugin: plugin, plugs: plugs)
            }
        }
    }

    fileprivate func updatePrinterFromCancelObjectPlugin(printer: Printer, plugins: NSDictionary) {
        var installed = false
        var ignored: String?
        if let cancelPlugin = plugins[Plugins.CANCEL_OBJECT] as? NSDictionary {
            // Cancel Object plugin is installed
            installed = true
            ignored = cancelPlugin["ignored"] as? String
        }
        if printer.cancelObjectInstalled != installed || printer.cancelObjectIgnored != ignored {
            let newObjectContext = printerManager.newPrivateContext()
            let printerToUpdate = newObjectContext.object(with: printer.objectID) as! Printer
            // Update flag that tracks if Cancel Object plugin is installed
            printerToUpdate.cancelObjectInstalled = installed
            printerToUpdate.cancelObjectIgnored = ignored
            // Persist updated printer
            printerManager.updatePrinter(printerToUpdate, context: newObjectContext)
            
            // Notify listeners of change
            for delegate in octoPrintSettingsDelegates {
                delegate.cancelObjectAvailabilityChanged(installed: installed)
            }
        }
    }
    
    fileprivate func updatePrinterFromOctorelayPlugin(printer: Printer, plugins: NSDictionary) {
        var installed = false
        if let _ = plugins[Plugins.OCTO_RELAY] as? NSDictionary {
            // Octorelay plugin is installed
            installed = true
        }
        if printer.octorelayInstalled != installed {
            let newObjectContext = printerManager.newPrivateContext()
            let printerToUpdate = newObjectContext.object(with: printer.objectID) as! Printer
            // Update flag that tracks if Octorelay plugin is installed
            printerToUpdate.octorelayInstalled = installed
            // Persist updated printer
            printerManager.updatePrinter(printerToUpdate, context: newObjectContext)
            
            // Notify listeners of change
            for delegate in octoPrintSettingsDelegates {
                delegate.octorelayAvailabilityChanged(installed: installed)
            }
        }
    }
    
    fileprivate func updatePrinterFromOctoPodPlugin(printer: Printer, plugins: NSDictionary) {
        let currentPrinterID = printer.objectID.uriRepresentation().absoluteString
        var installed = false
        var notificationToken: String?
        var octopodPluginPrinterName: String?
        var octopodPluginLanguage: String?
        if let octopodPlugin = plugins[Plugins.OCTOPOD] as? NSDictionary {
            // OctoPod plugin is installed
            installed = true
            // Retrieve last APNS token registered with the plugin for this printer
            if let registeredTokens = octopodPlugin["tokens"] as? NSArray {
                for case let registeredToken as NSDictionary in registeredTokens {
                    if let printerID = registeredToken["printerID"] as? String, let apnsToken = registeredToken["apnsToken"] as? String {
                        if printerID == currentPrinterID {
                            notificationToken = apnsToken
                            octopodPluginPrinterName = registeredToken["printerName"] as? String
                            octopodPluginLanguage = registeredToken["languageCode"] as? String
                            break
                        }
                    }
                }
            }
        }
        if printer.octopodPluginInstalled != installed || printer.notificationToken == nil || printer.notificationToken != notificationToken || printer.octopodPluginPrinterName != octopodPluginPrinterName || printer.octopodPluginLanguage != octopodPluginLanguage {
            let newObjectContext = printerManager.newPrivateContext()
            let printerToUpdate = newObjectContext.object(with: printer.objectID) as! Printer
            // Update flag that tracks if OctoPod plugin is installed
            printerToUpdate.octopodPluginInstalled = installed
            printerToUpdate.notificationToken = notificationToken
            printerToUpdate.octopodPluginPrinterName = octopodPluginPrinterName
            printerToUpdate.octopodPluginLanguage = octopodPluginLanguage
            // Persist updated printer
            printerManager.updatePrinter(printerToUpdate, context: newObjectContext)
            
            // Notify listeners of change
            for delegate in octoPrintSettingsDelegates {
                delegate.octoPodPluginChanged(installed: installed)
            }
        }
    }
    
    fileprivate func updatePrinterFromPalette2Plugin(printer: Printer, plugins: NSDictionary) {
        var installed = false
        var autoConnect = false
        if let palette2Plugin = plugins[Plugins.PALETTE_2] as? NSDictionary {
            // Palette2 plugin is installed
            installed = true
            if let autoconnect = palette2Plugin["autoconnect"] as? Bool {
                autoConnect = autoconnect
            }
        }

        // Force donating new Intent if first time running version 3.0
        // No need to ask users to uninstall and install Palette plugin
        let donatedUpgradeKey = "OCTOPOD_3_0:PALETTE2_FORCE_DONATION"
        var forceDonation = true
        let defaults = UserDefaults.standard
        if let donatedUpgrade = defaults.object(forKey: donatedUpgradeKey) as? Bool, donatedUpgrade {
            forceDonation = false
        }

        if forceDonation || printer.palette2Installed != installed || printer.palette2AutoConnect != autoConnect {
            let newObjectContext = printerManager.newPrivateContext()
            let printerToUpdate = newObjectContext.object(with: printer.objectID) as! Printer
            // Update flag that tracks if Palette2 plugin is installed
            printerToUpdate.palette2Installed = installed
            printerToUpdate.palette2AutoConnect = autoConnect
            // Persist updated printer
            printerManager.updatePrinter(printerToUpdate, context: newObjectContext)
            
            #if os(iOS)
                // Donate Siri commands to control Palette (or delete donated commands)
                if installed {
                    IntentsDonations.donatePaletteIntents(printer: printer)
                    // Indicate that donations of release 3.0 have been done
                    defaults.set(true, forKey: donatedUpgradeKey)
                } else {
                    IntentsDonations.deletePaletteIntents(printer: printer)
                }
            #endif
            
            // Notify listeners of change
            for delegate in octoPrintSettingsDelegates {
                delegate.palette2Changed(installed: installed)
            }
        }
    }
    
    fileprivate func updatePrinterFromPalette2CanvasPlugin(printer: Printer, plugins: NSDictionary) {
        var installed = false
        if let _ = plugins[Plugins.PALETTE_2_CANVAS] as? NSDictionary {
            // Palette2 Canvas plugin is installed
            installed = true
        }
        if printer.palette2CanvasInstalled != installed {
            let newObjectContext = printerManager.newPrivateContext()
            let printerToUpdate = newObjectContext.object(with: printer.objectID) as! Printer
            // Update flag that tracks if Palette2 Canvas plugin is installed
            printerToUpdate.palette2CanvasInstalled = installed
            // Persist updated printer
            printerManager.updatePrinter(printerToUpdate, context: newObjectContext)
            
            // Notify listeners of change
            for delegate in octoPrintSettingsDelegates {
                delegate.palette2CanvasAvailabilityChanged(installed: installed)
            }
        }
    }
    
    fileprivate func updatePrinterFromEnclosurePlugin(printer: Printer, plugins: NSDictionary) {
        if let enclosurePlugin = plugins[Plugins.ENCLOSURE] as? NSDictionary {
            if let rpiInputs = enclosurePlugin["rpi_inputs"] as? NSArray {
                var foundIds: Array<Int16> = Array()
                var inputsChanged = false
                for case let rpiInput as NSDictionary in rpiInputs {
                    if let index_id = rpiInput["index_id"] as? Int16, let inputType = rpiInput["input_type"] as? String, let label = rpiInput["label"] as? String, let useFahrenheit = rpiInput["use_fahrenheit"] as? Bool {
                        // Remember id that was seen. We will use this to know which ones to delete (if any)
                        foundIds.append(index_id)
                        var found = false
                        if let existingInputs = printer.enclosureInputs {
                            for enclosureInput in existingInputs {
                                if enclosureInput.index_id == index_id {
                                    found = true
                                    // Check that values are current
                                    if enclosureInput.type != inputType || enclosureInput.label != label || enclosureInput.use_fahrenheit != useFahrenheit {
                                        // Update existing input
                                        let newObjectContext = printerManager.newPrivateContext()
                                        let enclosureInputToUpdate = newObjectContext.object(with: enclosureInput.objectID) as! EnclosureInput
                                        enclosureInputToUpdate.type = inputType
                                        enclosureInputToUpdate.label = label
                                        enclosureInputToUpdate.use_fahrenheit = useFahrenheit
                                        // Persist updated EnclosureInput
                                        printerManager.saveObject(enclosureInputToUpdate, context: newObjectContext)
                                        
                                        inputsChanged = true
                                        break
                                    }
                                }
                            }
                        }
                        if !found {
                            // Add new input
                            let newObjectContext = printerManager.newPrivateContext()
                            let printerToUpdate = newObjectContext.object(with: printer.objectID) as! Printer
                            printerManager.addEnclosureInput(index: index_id, type: inputType, label: label, useFahrenheit: useFahrenheit, context: newObjectContext, printer: printerToUpdate)
                            inputsChanged = true
                        }
                    }
                }
                // Delete existing inputs that no longer exist
                if let existingInputs = printer.enclosureInputs {
                    for enclosureInput in existingInputs {
                        if !foundIds.contains(enclosureInput.index_id) {
                            // Delete input that no longer exists on the server
                            let newObjectContext = printerManager.newPrivateContext()
                            let enclosureInputToDelete = newObjectContext.object(with: enclosureInput.objectID) as! EnclosureInput
                            printerManager.deleteObject(enclosureInputToDelete, context: newObjectContext)
                            inputsChanged = true
                        }
                    }
                }

                if inputsChanged {
                    // Notify listeners of change
                    for delegate in octoPrintSettingsDelegates {
                        delegate.enclosureInputsChanged()
                    }
                }
            }
            if let rpiOutputs = enclosurePlugin["rpi_outputs"] as? NSArray {
                var foundIds: Array<Int16> = Array()
                var outputsChanged = false
                for case let rpiOutput as NSDictionary in rpiOutputs {
                    if let index_id = rpiOutput["index_id"] as? Int16, let outputType = rpiOutput["output_type"] as? String, let label = rpiOutput["label"] as? String, let hidden = rpiOutput["hide_btn_ui"] as? Bool {
                        if hidden {
                            // Output that are hidden from ui are treated as if they do not exist
                            continue
                        }
                        // Remember id that was seen. We will use this to know which ones to delete (if any)
                        foundIds.append(index_id)
                        var found = false
                        if let existingOutputs = printer.enclosureOutputs {
                            for existingOutput in existingOutputs {
                                if existingOutput.index_id == index_id {
                                    found = true
                                    // Check that values are current
                                    if existingOutput.type != outputType || existingOutput.label != label {
                                        // Update existing input
                                        let newObjectContext = printerManager.newPrivateContext()
                                        let enclosureOutputToUpdate = newObjectContext.object(with: existingOutput.objectID) as! EnclosureOutput
                                        enclosureOutputToUpdate.type = outputType
                                        enclosureOutputToUpdate.label = label
                                        // Persist updated EnclosureOutput
                                        printerManager.saveObject(enclosureOutputToUpdate, context: newObjectContext)
                                        
                                        outputsChanged = true
                                        break
                                    }
                                }
                            }
                        }
                        if !found {
                            // Add new input
                            let newObjectContext = printerManager.newPrivateContext()
                            let printerToUpdate = newObjectContext.object(with: printer.objectID) as! Printer
                            printerManager.addEnclosureOutput(index: index_id, type: outputType, label: label, context: newObjectContext, printer: printerToUpdate)
                            outputsChanged = true
                        }
                    }
                }
                // Delete existing inputs that no longer exist
                if let existingOutputs = printer.enclosureOutputs {
                    for existingOutput in existingOutputs {
                        if !foundIds.contains(existingOutput.index_id) {
                            // Delete input that no longer exists on the server
                            let newObjectContext = printerManager.newPrivateContext()
                            let enclosureOutputToDelete = newObjectContext.object(with: existingOutput.objectID) as! EnclosureOutput
                            printerManager.deleteObject(enclosureOutputToDelete, context: newObjectContext)
                            outputsChanged = true
                        }
                    }
                }

                if outputsChanged {
                    // Notify listeners of change
                    for delegate in octoPrintSettingsDelegates {
                        delegate.enclosureOutputsChanged()
                    }
                }
            }
        }
    }
    
    fileprivate func updatePrinterFromFilamentManagerPlugin(printer: Printer, plugins: NSDictionary) {
        var installed = false
        if let _ = plugins[Plugins.FILAMENT_MANAGER] as? NSDictionary {
            // FilamentManager plugin is installed
            installed = true
        }
        if printer.filamentManagerInstalled != installed {
            let newObjectContext = printerManager.newPrivateContext()
            let printerToUpdate = newObjectContext.object(with: printer.objectID) as! Printer
            // Update flag that tracks if FilamentManager plugin is installed
            printerToUpdate.filamentManagerInstalled = installed
            // Persist updated printer
            printerManager.updatePrinter(printerToUpdate, context: newObjectContext)
            
            // Notify listeners of change
            for delegate in octoPrintSettingsDelegates {
                delegate.filamentManagerAvailabilityChanged(installed: installed)
            }
        }
    }
    
    fileprivate func updatePrinterFromBLTouchPlugin(printer: Printer, plugins: NSDictionary) {
        if let pluginSettings = plugins[Plugins.BL_TOUCH] as? NSDictionary {
            // BLTouch plugin is installed
            var changed = false
            if let probeUp = pluginSettings["cmdProbeUp"] as? String, let probeDown = pluginSettings["cmdProbeDown"] as? String, let selfTest = pluginSettings["cmdSelfTest"] as? String, let releaseAlarm = pluginSettings["cmdReleaseAlarm"] as? String, let probeBed = pluginSettings["cmdProbeBed"] as? String, let saveSettings = pluginSettings["cmdSaveSettings"] as? String {
                
                if let blTouch = printer.blTouch {
                    if blTouch.cmdProbeUp != probeUp || blTouch.cmdProbeDown != probeDown || blTouch.cmdSelfTest != selfTest || blTouch.cmdReleaseAlarm != releaseAlarm || blTouch.cmdProbeBed != probeBed || blTouch.cmdSaveSettings != saveSettings {
                        // Update BLTouch instance with settings of plugin
                        let newObjectContext = printerManager.newPrivateContext()
                        let blTouchToUpdate = newObjectContext.object(with: blTouch.objectID) as! BLTouch
                        // Update BLTouch plugin settings
                        blTouchToUpdate.cmdProbeUp = probeUp
                        blTouchToUpdate.cmdProbeDown = probeDown
                        blTouchToUpdate.cmdSelfTest = selfTest
                        blTouchToUpdate.cmdReleaseAlarm = releaseAlarm
                        blTouchToUpdate.cmdProbeBed = probeBed
                        blTouchToUpdate.cmdSaveSettings = saveSettings

                        // Persist updated printer
                        if printerManager.saveObject(blTouchToUpdate, context: newObjectContext) {
                            changed = true
                        } else {
                            NSLog("Failed to update BLTouch settings in core data")
                        }
                    }
                } else {
                    // Create new BLTouch instance with settings of plugin
                    let newObjectContext = printerManager.newPrivateContext()
                    let printerToUpdate = newObjectContext.object(with: printer.objectID) as! Printer
                    // Update BLTouch plugin settings
                    if printerManager.addBLTouch(cmdProbeUp: probeUp, cmdProbeDown: probeDown, cmdSelfTest: selfTest, cmdReleaseAlarm: releaseAlarm, cmdProbeBed: probeBed, cmdSaveSettings: saveSettings, context: newObjectContext, printer: printerToUpdate) {
                        changed = true
                    } else {
                        NSLog("Failed to create BLTouch settings in core data")
                    }
                }
                if changed {
                    // Notify listeners of change
                    for delegate in octoPrintSettingsDelegates {
                        delegate.blTouchSettingsChanged(installed: true)
                    }
                }
            }
        } else {
            // BLTouch not installed
            if let _ = printer.blTouch {
                // Delete existing blTouch settings
                let newObjectContext = printerManager.newPrivateContext()
                let printerToUpdate = newObjectContext.object(with: printer.objectID) as! Printer
                printerToUpdate.blTouch = nil
                printerManager.updatePrinter(printerToUpdate, context: newObjectContext)

                // Notify listeners of change
                for delegate in octoPrintSettingsDelegates {
                    delegate.blTouchSettingsChanged(installed: false)
                }
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
                    
                    let newObjectContext = printerManager.newPrivateContext()
                    let printerToUpdate = newObjectContext.object(with: printer.objectID) as! Printer

                    var changedX = false
                    var changedY = false
                    var changedZ = false
                    // Update camera orientation
                    if printer.invertX != invertedX {
                        printerToUpdate.invertX = invertedX
                        changedX = true
                    }
                    if printer.invertY != invertedY {
                        printerToUpdate.invertY = invertedY
                        changedY = true
                    }
                    if printer.invertZ != invertedZ {
                        printerToUpdate.invertZ = invertedZ
                        changedZ = true
                    }
                    // Persist updated printer
                    if changedX || changedY || changedZ {
                        printerManager.updatePrinter(printerToUpdate, context: newObjectContext)
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
                if let extruder = currentProfile["extruder"] as? NSDictionary {
                    if let extruderCount = extruder["count"] as? Int16, let sharedNozzle = extruder["sharedNozzle"] as? Bool {
                        updatePrinterToolsNumber(printer: printer, toolsNumber: extruderCount, sharedNozzle: sharedNozzle)
                    }
                }
            }
        }
    }
    
    fileprivate func updatePrinterToolsNumber(printer: Printer, toolsNumber: Int16, sharedNozzle: Bool) {
        if printer.toolsNumber != toolsNumber || printer.sharedNozzle != sharedNozzle {
            let newObjectContext = printerManager.newPrivateContext()
            let printerToUpdate = newObjectContext.object(with: printer.objectID) as! Printer
            // Update detected number of tools installed in the printer
            printerToUpdate.toolsNumber = toolsNumber
            printerToUpdate.sharedNozzle = sharedNozzle
            // Persist updated printer
            printerManager.updatePrinter(printerToUpdate, context: newObjectContext)
            
            if printerToUpdate.defaultPrinter {
                webSocketClient?.sharedNozzle = sharedNozzle
            }

            for delegate in printerProfilesDelegates {
                delegate.toolsChanged(toolsNumber: toolsNumber, sharedNozzle: sharedNozzle)
            }
        }
    }
}
