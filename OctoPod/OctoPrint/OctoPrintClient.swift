import Foundation
import UIKit

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
    
    var delegates: Array<OctoPrintClientDelegate> = Array()
    var octoPrintSettingsDelegates: Array<OctoPrintSettingsDelegate> = Array()
    var printerProfilesDelegates: Array<PrinterProfilesDelegate> = Array()
    var octoPrintPluginsDelegates: Array<OctoPrintPluginsDelegate> = Array()
    
    var appConfiguration: AppConfiguration {
        get {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            return appDelegate.appConfiguration
        }
        set(configuration) {
            configuration.delegates.append(self)
        }
    }

    // Remember last CurrentStateEvent that was reported from OctoPrint (via websockets)
    var lastKnownState: CurrentStateEvent?
    var octoPrintVersion: String?
    
    init(printerManager: PrinterManager) {
        self.printerManager = printerManager
        self.octoPrintRESTClient = OctoPrintRESTClient()
        // Configure REST client to show network activity in iOS app when making requests
        self.octoPrintRESTClient.preRequest = {
            DispatchQueue.main.async(execute: { () -> Void in UIApplication.shared.isNetworkActivityIndicatorVisible = true })
        }
        self.octoPrintRESTClient.postRequest = {
            DispatchQueue.main.async(execute: { () -> Void in UIApplication.shared.isNetworkActivityIndicatorVisible = false })
        }
    }
    
    // MARK: - OctoPrint server connection
    
    /// Connect to OctoPrint server and gather printer state
    /// A websocket connection will be attempted to get real time updates from OctoPrint
    /// An HTTPClient is created for sending requests to OctoPrint
    func connectToServer(printer: Printer) {
        // Clean up any known printer state
        lastKnownState = nil
        
        // Create and keep httpClient while default printer does not change
        octoPrintRESTClient.connectToServer(serverURL: printer.hostname, apiKey: printer.apiKey, username: printer.username, password: printer.password)
        
        if webSocketClient?.isConnected(printer: printer) == true {
            // Do nothing since we are already connected to the default printer
            return
        }
        
        for delegate in delegates {
            delegate.notificationAboutToConnectToServer()
        }
        
        // Clean up any temp history
        tempHistory.clear()
        
        // We need to rediscover the version of OctoPrint so clean up old values
        octoPrintVersion = nil
        
        // Close any previous connection
        webSocketClient?.closeConnection()
        
        // Notify the terminal that we are about to connect to OctoPrint
        terminal.websocketNewConnection()
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
        
        // Discover OctoPrint version
        octoPrintRESTClient.versionInformation { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
            if let json = result as? NSDictionary {
                if let server = json["server"] as? String {
                    self.octoPrintVersion = server
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
        } else {
            // Return that there were no errors
            return false
        }
    }

    // MARK: - WebSocketClientDelegate
    
    /// Notification that OctoPrint state has changed. This may include printer status information
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
    
    /// Notification that contains history of temperatures. This information is received once after
    /// websocket connection was established. #currentStateUpdated contains new temps after this event
    func historyTemp(history: Array<TempHistory.Temp>) {
        tempHistory.addHistory(history: history)
    }
    
    /// Notifcation that OctoPrint's settings has changed
    func octoPrintSettingsUpdated() {
        if let printer = printerManager.getDefaultPrinter() {
            // Verify that last known settings are still current
            reviewOctoPrintSettings(printer: printer)
        }
    }
    
    /// Notification sent by plugin via websockets
    /// - Parameters:
    ///     - plugin: identifier of the OctoPrint plugin
    ///     - data: whatever JSON data structure sent by the plugin
    ///
    /// Example: {data: {isPSUOn: false, hasGPIO: true}, plugin: "psucontrol"}
    func pluginMessage(plugin: String, data: NSDictionary) {
        // Notify other listeners that we connected to OctoPrint
        for delegate in octoPrintPluginsDelegates {
            delegate.pluginMessage(plugin: plugin, data: data)
        }
    }

    /// Notification sent when websockets got connected
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
    
    /// Notification sent when websockets got disconnected due to an error (or failed to connect)
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
        if let printer = printerManager.getDefaultPrinter() {
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

                    return opMajor >= major && opMinor >= minor && opPatch >= patch
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
    
    func home(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.home(callback: callback)
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

    // MARK: - Custom Controls operations

    func customControls(callback: @escaping (Array<Container>?, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.customControls(callback: callback)
    }
    
    func executeCustomControl(control: NSDictionary, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
       octoPrintRESTClient.executeCustomControl(control: control, callback: callback)
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
        octoPrintRESTClient.getCancelObjects(callback: callback)
    }
    
    /// Cancel the requested object id.
    func cancelObject(id: Int, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.cancelObject(id: id, callback: callback)
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

        if let webcam = json["webcam"] as? NSDictionary {
            if let flipH = webcam["flipH"] as? Bool, let flipV = webcam["flipV"] as? Bool, let rotate90 = webcam["rotate90"] as? Bool {
                let newOrientation = calculateImageOrientation(flipH: flipH, flipV: flipV, rotate90: rotate90)
                if printer.cameraOrientation != newOrientation.rawValue {
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
        updatePrinterFromTasmotaPlugin(printer: printer, plugins: plugins)
        updatePrinterFromCancelObjectPlugin(printer: printer, plugins: plugins)
        updatePrinterFromOctoPodPlugin(printer: printer, plugins: plugins)
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
            let newObjectContext = printerManager.newPrivateContext()
            let printerToUpdate = newObjectContext.object(with: printer.objectID) as! Printer
            // Update array
            printerToUpdate.cameras = camerasURLs
            // Persist updated printer
            printerManager.updatePrinter(printerToUpdate, context: newObjectContext)
            
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
        if let _ = plugins[Plugins.CANCEL_OBJECT] as? NSDictionary {
            // Cancel Object plugin is installed
            installed = true
        }
        if printer.cancelObjectInstalled != installed {
            let newObjectContext = printerManager.newPrivateContext()
            let printerToUpdate = newObjectContext.object(with: printer.objectID) as! Printer
            // Update flag that tracks if Cancel Object plugin is installed
            printerToUpdate.cancelObjectInstalled = installed
            // Persist updated printer
            printerManager.updatePrinter(printerToUpdate, context: newObjectContext)
            
            // Notify listeners of change
            for delegate in octoPrintSettingsDelegates {
                delegate.cancelObjectAvailabilityChanged(installed: installed)
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
            }
        }
    }
}
