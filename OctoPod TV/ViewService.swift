import Foundation

class ViewService: ObservableObject, WebSocketClientDelegate {
    @Published var printerStatus: String = "--"
    @Published var printingFile: String = "--"
    @Published var progress: String = "--%"
    @Published var printTime: String = "--"
    @Published var printTimeLeft: String = "--"
    @Published var printEstimatedCompletion: String = "--"
    @Published var tool0Actual: String = "--C"
    @Published var tool0Target: String = "--C"
    @Published var bedActual: String = "--C"
    @Published var bedTarget: String = "--C"
    @Published var currentHeight: String?
    @Published var layer: String?

    var octoPrintRESTClient = OctoPrintRESTClient()
    var webSocketClient: WebSocketClient?
    
    init() {
        self.clearValues()
    }
    
    func clearValues() {
        printerStatus = "--"
        printingFile = "--"
        progress = "--%"
        printTime = "--"
        printTimeLeft = "--"
        printEstimatedCompletion = "--"
        tool0Actual = "--C"
        tool0Target = "--C"
        bedActual = "--C"
        bedTarget = "--C"
        currentHeight = nil
        layer = nil
    }
    
    func connectToServer(printer: Printer) {
        // Create and keep httpClient while default printer does not change
        octoPrintRESTClient.connectToServer(serverURL: printer.hostname, apiKey: printer.apiKey, username: printer.username, password: printer.password)
        
        if webSocketClient?.isConnected(printer: printer) == true {
            // Do nothing since we are already connected to the default printer
            return
        }
    
        // Close any previous connection
        webSocketClient?.closeConnection()
        
        // Notify the terminal that we are about to connect to OctoPrint
//        terminal.websocketNewConnection()
        // Create websocket connection and connect
        webSocketClient = WebSocketClient(printer: printer)
        // Subscribe to events so we can update the UI as events get pushed
        webSocketClient?.delegate = self
}

    // MARK: - WebSocketClientDelegate
    
    func currentStateUpdated(event: CurrentStateEvent) {
        // Update properties from event. This will fire event that will refresh UI
        DispatchQueue.main.async {
            if let state = event.state {
                self.printerStatus = state
            }

            if let printFile = event.printFile, let printFileName = printFile.name {
                self.printingFile = printFileName
            }

            if let progress = event.progressCompletion {
                let progressText = String(format: "%.1f", progress)
                self.progress = "\(progressText)%"
            }

            if let seconds = event.progressPrintTime {
                self.printTime = self.secondsToPrintTime(seconds: seconds)
            }

            if let seconds = event.progressPrintTimeLeft {
                self.printTimeLeft = UIUtils.secondsToTimeLeft(seconds: seconds, ifZero: "")
                self.printEstimatedCompletion = UIUtils.secondsToETA(seconds: seconds)
            } else if event.progressPrintTime != nil {
                self.printTimeLeft = NSLocalizedString("Still stabilizing", comment: "Print time is being calculated")
                self.printEstimatedCompletion = ""
            }

            if let tool0Actual = event.tool0TempActual {
                self.tool0Actual = "\(String(format: "%.1f", tool0Actual)) C"
            }
            if let tool0Target = event.tool0TempTarget {
                self.tool0Target = "\(String(format: "%.0f", tool0Target)) C"
            }

            if let bedActual = event.bedTempActual {
                self.bedActual = "\(String(format: "%.1f", bedActual)) C"
            }
            if let bedTarget = event.bedTempTarget {
                self.bedTarget = "\(String(format: "%.0f", bedTarget)) C"
            }
        }
    }
    
    func historyTemp(history: Array<TempHistory.Temp>) {
    }
    
    func octoPrintSettingsUpdated() {
//        if let printer = printerManager.getDefaultPrinter() {
//            // Verify that last known settings are still current
//            reviewOctoPrintSettings(printer: printer)
//        }
    }
    
    func printerProfileUpdated() {
//        if let printer = printerManager.getDefaultPrinter() {
//            // Update Printer from /api/printerprofiles information
//            reviewPrinterProfile(printer: printer)
//        }
    }
    
    func pluginMessage(plugin: String, data: NSDictionary) {
        if plugin == Plugins.DISPLAY_LAYER_PROGRESS {
            if let stateMessage = data["stateMessage"] as? String, let heightMessage = data["heightMessage"] as? String {
                // Refresh UI
                DispatchQueue.main.async {
                    self.currentHeight = heightMessage
                    self.layer = stateMessage
                }
            }
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
            
//            // Notify the terminal that we connected to OctoPrint
//            self.terminal.websocketConnected()
            // Notify other listeners that we connected to OctoPrint
//            for delegate in self.delegates {
//                delegate.websocketConnected()
//            }
        }
    }
    
    func websocketConnectionFailed(error: Error) {
//        for delegate in delegates {
//            delegate.websocketConnectionFailed(error: error)
//        }
    }

    // MARK: - Login operations

    /// Passive login has been added to OctoPrint 1.3.10 to increase security. Endpoint existed before
    /// but without passive mode. New version returns a "session" field that is used by websockets to
    /// allow websockets to work when Forcelogin Plugin is active (the default)
    fileprivate func passiveLogin(callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.passiveLogin(callback: callback)
    }

    // MARK: - Private functions

    /// Converts number of seconds into a string that represents time (e.g. 23h 10m)
    func secondsToPrintTime(seconds: Int) -> String {
        let duration = TimeInterval(seconds)
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .brief
        formatter.allowedUnits = [ .day, .hour, .minute, .second ]
        formatter.zeroFormattingBehavior = [ .default ]
        return formatter.string(from: duration)!
    }
}
