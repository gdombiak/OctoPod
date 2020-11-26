import Foundation
import UIKit
import WatchConnectivity

class WatchSessionManager: NSObject, WCSessionDelegate, CloudKitPrinterDelegate, OctoPrintSettingsDelegate {

    var printerManager: PrinterManager
    var octoprintClient: OctoPrintClient
    var session: WCSession?
    
    var delegates: Array<WatchSessionManagerDelegate> = []
    
    private var lastPushComplicationUpdate: Date?
    private var lastPushedCompletion: Double?
    
    // We need to keep this as an instance variable so it is not garbage collected and crashes
    // the app since it uses KVO which crashes if observer has been GC'ed
    private var hlsThumbnailGenerator: HLSThumbnailUtil?

    init(printerManager: PrinterManager, cloudKitPrinterManager: CloudKitPrinterManager, octoprintClient: OctoPrintClient) {
        self.printerManager = printerManager
        self.octoprintClient = octoprintClient
        super.init()
        
        // Listen to changes to OctoPrint Settings
        octoprintClient.octoPrintSettingsDelegates.append(self)

        // Listen to iCloud changes. Printers may be modified from iPad and
        // when iPhone gets notified then we will reach and push to Apple Watch
        cloudKitPrinterManager.delegates.append(self)
    }

    func start() {
        if (WCSession.isSupported()) {
            session = WCSession.default
            
            session!.delegate = self
            session!.activate()
        } else {
            NSLog("WatchConnectivity is not supported on this device")
        }
    }
    
    // MARK: - Push information to Apple Watch

    /// Send printers information to Apple Watch
    func pushPrinters() {
        do {
            try getSession()?.updateApplicationContext(encodePrinters())
        }
        catch {
            NSLog("Failed to push printers as ApplicationContext. Error: \(error)")
        }
    }
    
    /// Send updated complication information to Apple Watch. Push is only done when printer changed state. Complications are also
    /// updated with a background refresh from the Apple Watch or when user opens Apple Watch app which results in fetching latest
    /// data.
    /// Push will be done only if Apple Watch has a complication installed. It will first be attempted via #transferCurrentComplicationUserInfo
    /// if there is still budget. If not the same information will be sent via updateApplicationContext as a fallback mechanism
    func updateComplications(printerName: String, printerState: String, completion: Double?, useBudget: Bool) {
        if let session = getSession(), session.activationState == .activated {
            var info = ["printer": printerName, "state": printerState, "completion": completion ?? 0.0] as [String : Any]
            let complicationRequest = ["complications" : info]
            
            let transmitDataBlock = {
                if session.isComplicationEnabled {
                    if useBudget && session.remainingComplicationUserInfoTransfers > 0 {
                        // We can update complications using high priority #transferCurrentComplicationUserInfo
                        session.transferCurrentComplicationUserInfo(complicationRequest)
                        // Remember last time we requested to update complication
                        self.lastPushComplicationUpdate = Date()
                        self.lastPushedCompletion = completion
                    } else {
                        if useBudget {
                            NSLog("Out of budget so updating complications via #updateApplicationContext")
                        } else {
                            NSLog("Requested to send complication update as low priority to not consume budget")
                        }
                        // We are out of budget so attempt updating complications this other way
                        do {
                            try session.updateApplicationContext(complicationRequest)
                            // Remember last time we requested to update complication
                            self.lastPushComplicationUpdate = Date()
                            self.lastPushedCompletion = completion
                        }
                        catch {
                            NSLog("Failed to request WatchOS app to update context \(complicationRequest). Error: \(error)")
                        }
                    }
                } else {
                    NSLog("Complication not installed on Apple Watch")
                }
            }
            
            let tuple = restClientToPrinter(printerName: printerName)
            let restClient: OctoPrintRESTClient? = tuple.restClient
            let palette2PluginInstalled = tuple.palette2PluginInstalled
            if restClient == nil || !palette2PluginInstalled {
                transmitDataBlock()
            } else {
                // Gather now Palette 2 pings stats
                if palette2PluginInstalled {
                    restClient!.palette2PingHistory(plugin: Plugins.PALETTE_2) { (lastPing: (number: String, percent: String, variance: String)?, pingStats: (max: String, average: String, min: String)?, error: Error?, response: HTTPURLResponse) in
                        if let lastPing = lastPing, let pingStats = pingStats {
                            info["palette2LastPing"] = lastPing.percent
                            info["palette2LastVariation"] = lastPing.variance
                            info["palette2MaxVariation"] = pingStats.max
                        }
                        // Send data to Apple Watch with updated data including Palette 2 pings information
                        transmitDataBlock()
                    }
                } else {
                    // Send data to Apple Watch with whatever data we have
                    transmitDataBlock()
                }
            }
        }
    }
    
    /// Printer is printing and made more progress so check if it is time to request complications to be updated. There is a daily budget on
    /// the Apple Watch for updating complications so we need to be carefull frequency for updating things. Not updating enough is also bad
    /// since users will find complications useless
    func optionalUpdateComplications(printerName: String, printerState: String, completion: Double, forceUpdate: Bool) {
        if let session = getSession(), session.activationState == .activated, session.isComplicationEnabled {
            if forceUpdate {
                // Check if progress is bigger by 10%
                if completion - (lastPushedCompletion ?? 0) > 10 {
                    // Request to update complications and use #transferCurrentComplicationUserInfo budget
                    updateComplications(printerName: printerName, printerState: printerState, completion: completion, useBudget: true)
                }
            } else {
                if let lastPushedDate = lastPushComplicationUpdate, let lastPushedCompletion = lastPushedCompletion {
                    let elapsedSeconds = Date().timeIntervalSince(lastPushedDate)
                    // Check if progress is bigger by 10% and it has been at least 10 minutes since last update (or we started a new print)
                    if (completion - lastPushedCompletion > 10 && elapsedSeconds >= 600) || completion < lastPushedCompletion {
                        // Request to update complications but without consuming #transferCurrentComplicationUserInfo budget
                        // since frequency of this type of updates could be high
                        updateComplications(printerName: printerName, printerState: printerState, completion: completion, useBudget: false)
                    }
                } else {
                    // No complication update has been sent yet (that we tracked) so start counting from this point
                    self.lastPushComplicationUpdate = Date()
                    self.lastPushedCompletion = completion
                }
            }
        }
    }
    
    /// Tell the Apple Watch to use the specified content type when rendering complications. Dependeing on
    /// the complication, the content may not be rendered or may replace another text or may be appended
    /// - parameter contentType: Possible values are: defaultText, palette2LastPing, palette2LastVariation, palette2MaxVariation
    func updateComplicationsContentType(contentType: ComplicationContentType.Choice) {
        if let session = getSession(), session.activationState == .activated {
            let contentTypeRequest = ["complications:content_type" : "\(contentType)"]
            do {
                try session.updateApplicationContext(contentTypeRequest)
            }
            catch {
                NSLog("Failed to request WatchOS app to update context \(contentTypeRequest). Error: \(error)")
            }
        }
    }

    // MARK: - WCSessionDelegate
    
    /** Called when the session has completed activation. If session state is WCSessionActivationStateNotActivated there will be an error with more details. */
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
    }
    
    
    /** Called when the session can no longer be used to modify or add any new transfers and, all interactive messages will be cancelled, but delegate callbacks for background transfers can still occur. This will happen when the selected watch is being changed. */
    public func sessionDidBecomeInactive(_ session: WCSession) {
        
    }
    
    
    /** Called when all delegate callbacks for the previously selected watch has occurred. The session can be re-activated for the now selected watch using activateSession. */
    public func sessionDidDeactivate(_ session: WCSession) {
        
    }
    
    /** Called on the delegate of the receiver when the sender sends a message that expects a reply. Will be called on startup if the incoming message caused the receiver to launch. */
    public func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        if message["printers"] != nil {
            replyHandler(encodePrinters())
        } else if let printerName = message["panel_info"] as? String {
            panel_info(printerName: printerName, replyHandler: replyHandler)
        } else if let camera = message["camera_take"] as? Dictionary<String, Any> {
            camera_take(replyHandler, camera: camera)
        } else if let printerName = message["pause_job"] as? String {
            pause_job(printerName: printerName, replyHandler: replyHandler)
        } else if let printerName = message["resume_job"] as? String {
            resume_job(printerName: printerName, replyHandler: replyHandler)
        } else if let printerName = message["cancel_job"] as? String {
            cancel_job(printerName: printerName, replyHandler: replyHandler)
        } else {
            // Unkown request was received
            let reply = ["unknown" : ""]
            replyHandler(reply)
            NSLog("Unknown request for a response was received: \(message)")
        }
    }
    
    /** Called on the delegate of the receiver. Will be called on startup if an applicationContext is available. */
    public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        if applicationContext["selected_printer"] != nil {
            // Apple Watch marked a printer as the new selected on
            changeDefaultPrinter(printerName: applicationContext["selected_printer"] as! String)
        }
    }

    // MARK: - CloudKitPrinterDelegate
    
    func printersUpdated() {
        pushPrinters()
    }
    
    func printerAdded(printer: Printer) {
    }
    
    func printerUpdated(printer: Printer) {
    }
    
    func printerDeleted(printer: Printer) {
    }
    
    func iCloudStatusChanged(connected: Bool) {
    }
    
    // MARK: - OctoPrintSettingsDelegate
    
    func cameraOrientationChanged(newOrientation: UIImage.Orientation) {
        pushPrinters()
    }
    
    func cameraPathChanged(streamUrl: String) {
        pushPrinters()
    }
    
    func camerasChanged(camerasURLs: Array<String>) {
        pushPrinters()
    }

    // MARK: - Delegates operations
    
    func remove(watchSessionManagerDelegate toRemove: WatchSessionManagerDelegate) {
        delegates.removeAll(where: { $0 === toRemove })
    }

    // MARK: - Commands private functions
    
    fileprivate func changeDefaultPrinter(printerName: String) {
        if let printer = printerManager.getPrinterByName(name: printerName) {
            // Update stored printers
            printerManager.changeToDefaultPrinter(printer)
            // Ask octoprintClient to connect to new OctoPrint server
            octoprintClient.connectToServer(printer: printer)
            // Notify listeners of this change
            for delegate in delegates {
                delegate.defaultPrinterChanged()
            }
            // If not running in foreground then disconnect websocket
            // For some reason even if app is in background websocket remains open
            // and received data which potentially consumes cellular data
            DispatchQueue.main.async {
                if UIApplication.shared.applicationState != .active {
                    self.octoprintClient.disconnectFromServer()
                }
            }
        }
    }

    fileprivate func panel_info(printerName: String, replyHandler: @escaping ([String : Any]) -> Void) {
        // iOS app and Apple Watch may be working on different printers.
        // No need to force synch for this operation. If we do then a user that quickly
        // switches between printers from the iOS app may end up with the wrong printer since
        // the Apple Watch might be slow at getting the notification and it will ask for panel information
        // of a no longer selected printer and we do not want to revert it back to the old one. To prevent
        // all this problem we allow out-of-sync-selected printer for this operation only

        // If requested printer is selected printer then use existing REST client
        // if not then create a new REST client for this operation
        let tuple = restClientToPrinter(printerName: printerName)
        let restClient: OctoPrintRESTClient? = tuple.restClient
        let sharedNozzle: Bool = tuple.sharedNozzle
        let palette2PluginInstalled = tuple.palette2PluginInstalled
        if restClient == nil {
            replyHandler(["error": NSLocalizedString("No printer", comment: "")])
            return
        }
        
        // Execute request
        restClient!.currentJobInfo { (result: NSObject?, error: Error?, response :HTTPURLResponse) in
            if let error = error {
                replyHandler(["error": error.localizedDescription])
            } else if let result = result as? Dictionary<String, Any> {
                var reply: [String : Any] = [:]
                if let state = result["state"] as? String {
                    reply["state"] = state
                }
                if let progress = result["progress"] as? Dictionary<String, Any> {
                    if let completion = progress["completion"] as? Double {
                        reply["completion"] = completion
                    }
                    if let printTimeLeft = progress["printTimeLeft"] as? Int {
                        reply["printTimeLeft"] = printTimeLeft
                    } else if let _ = progress["printTime"] as? Int {
                        reply["printTimeLeft"] = NSLocalizedString("Still stabilizing", comment: "Print time is being calculated")
                    }
                }
                
                // Gather now info about printer (paused/printing/temps)
                restClient!.printerState { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                    if let json = result as? NSDictionary {
                        let event = CurrentStateEvent()
                        if let state = json["state"] as? NSDictionary {
                            event.parseState(state: state)

                            if event.printing  == true {
                                reply["printer"] = "printing"
                            } else if event.paused == true {
                                reply["printer"] = "paused"
                            } else if event.operational == true {
                                reply["printer"] = "operational"
                            }                            
                        }
                        if let temps = json["temperature"] as? NSDictionary {
                            event.parseTemps(temp: temps, sharedNozzle: sharedNozzle)

                            if let bedTemp = event.bedTempActual {
                                reply["bedTemp"] = bedTemp
                            }
                            if let toolTemp = event.tool0TempActual {
                                reply["tool0Temp"] = toolTemp
                            }
                            if let toolTemp = event.tool1TempActual {
                                reply["tool1Temp"] = toolTemp
                            }
                            if let toolTemp = event.tool2TempActual {
                                reply["tool2Temp"] = toolTemp
                            }
                            if let toolTemp = event.tool3TempActual {
                                reply["tool3Temp"] = toolTemp
                            }
                            if let toolTemp = event.tool4TempActual {
                                reply["tool4Temp"] = toolTemp
                            }
                            if let chamberTemp = event.chamberTempActual {
                                reply["chamberTemp"] = chamberTemp
                            }
                        }
                    }
                    
                    // Gather now Palette 2 pings stats
                    if palette2PluginInstalled {
                        restClient!.palette2PingHistory(plugin: Plugins.PALETTE_2) { (lastPing: (number: String, percent: String, variance: String)?, pingStats: (max: String, average: String, min: String)?, error: Error?, response: HTTPURLResponse) in
                            if let lastPing = lastPing, let pingStats = pingStats {
                                reply["palette2LastPing"] = lastPing.percent
                                reply["palette2LastVariation"] = lastPing.variance
                                reply["palette2MaxVariation"] = pingStats.max
                            }
                            // Send reply back to Apple Watch with results
                            replyHandler(reply)
                        }
                        
                    } else {
                        // Send reply back to Apple Watch with results
                        replyHandler(reply)
                    }
                }
            } else {
                if response.statusCode == 403 {
                    // Bad API Keys
                    replyHandler(["error": NSLocalizedString("Incorrect API Key", comment: "")])
                } else {
                    let message = String(format: NSLocalizedString("HTTP Request error", comment: "HTTP Request error info"), response.statusCode)
                    replyHandler(["error": message])
                }
            }
        }
    }
    
    fileprivate func camera_take(_ replyHandler: @escaping ([String : Any]) -> Void, camera: Dictionary<String, Any>) {
        if let url = camera["url"] as? String, let cameraId = camera["cameraId"] as? String {
            if let cameraURL = URL(string: url) {
                let screenWidth = camera["width"] as! Int
                let username = camera["username"] as? String
                let password = camera["password"] as? String
                var imageOrientation = UIImage.Orientation.up
                if let orientation = camera["orientation"] as? Int {
                    imageOrientation = UIImage.Orientation(rawValue: orientation)!
                }

                let completion = { (image: UIImage?, reply: [String : Any]?) in
                    if let image = image {
                        var newImage: UIImage = image
                        DispatchQueue.main.async {
                            // Resize image to save space
                            if let resizedImage = image.resizeWithWidth(width: CGFloat(screenWidth - 10)) {
                                newImage = resizedImage
                            } else {
                                NSLog("Failed to reduce image size")
                            }
                            // Save image to file with quality 80% to further reduce size. (Eg: 300KB -> 48K)
                            if let data = newImage.jpegData(compressionQuality: 0.80) {
                                if let fileURL = self.session?.watchDirectoryURL?.appendingPathComponent(UUID().uuidString) {
                                    do {
                                        try data.write(to: fileURL)
                                        // Send file to Apple Watch
                                        self.session?.transferFile(fileURL, metadata: ["cameraId": cameraId])
                                        // Send back confirmation that image file was created (DO WE NEED THIS)
                                        replyHandler(["done": ""])
                                    }
                                    catch {
                                        NSLog("Failed to save JPEG file. Error: \(error)")
                                        let message = NSLocalizedString("Failed to save JPEG file", comment: "")
                                        replyHandler(["error": message, "retry": true])
                                    }
                                    
                                } else {
                                    NSLog("WARNING - watchDirectoryURL seems to be NIL")
                                    let message = NSLocalizedString("Failed to save JPEG file", comment: "")
                                    replyHandler(["error": message, "retry": true])
                                }
                            } else {
                                let message = NSLocalizedString("Failed to save JPEG file", comment: "")
                                replyHandler(["error": message, "retry": true])
                            }
                        }
                    } else if let reply = reply {
                        // No image so reply is an error
                        replyHandler(reply)
                    }
                }
                
                if UIUtils.isHLS(url: url) {
                    renderHLSImage(cameraURL: cameraURL, imageOrientation: imageOrientation, username: username, password: password, completion: completion)
                } else {
                    renderMJPEGImage(cameraURL: cameraURL, imageOrientation: imageOrientation, username: username, password: password, completion: completion)
                }
            } else {
                NSLog("Invalid camera URL: \(url)")
                let message = NSLocalizedString("Invalid camera URL", comment: "")
                replyHandler(["error": message])
            }
        }
    }
    
    fileprivate func pause_job(printerName: String, replyHandler: @escaping ([String : Any]) -> Void) {
        // Make sure that iOS app and Apple Watch are operating on the same printer
        ensureDefaultPrinter(printerName: printerName)
        // Execute request
        self.octoprintClient.pauseCurrentJob { (requested: Bool, error: Error?, response: HTTPURLResponse) in
            if requested {
                replyHandler(["" : ""])
            } else {
                replyHandler(["error" : error == nil ? "Failed with no error!!" : error!.localizedDescription])
            }
        }
    }

    fileprivate func resume_job(printerName: String, replyHandler: @escaping ([String : Any]) -> Void) {
        // Make sure that iOS app and Apple Watch are operating on the same printer
        ensureDefaultPrinter(printerName: printerName)
        // Execute request
        self.octoprintClient.resumeCurrentJob { (requested: Bool, error: Error?, response: HTTPURLResponse) in
            if requested {
                replyHandler(["" : ""])
            } else {
                replyHandler(["error" : error == nil ? "Failed with no error!!" : error!.localizedDescription])
            }
        }
    }

    fileprivate func cancel_job(printerName: String, replyHandler: @escaping ([String : Any]) -> Void) {
        // Make sure that iOS app and Apple Watch are operating on the same printer
        ensureDefaultPrinter(printerName: printerName)
        // Execute request
        self.octoprintClient.cancelCurrentJob { (requested: Bool, error: Error?, response: HTTPURLResponse) in
            if requested {
                replyHandler(["" : ""])
            } else {
                replyHandler(["error" : error == nil ? "Failed with no error!!" : error!.localizedDescription])
            }
        }
    }

    // MARK: - Private functions
    
    fileprivate func renderMJPEGImage(cameraURL: URL, imageOrientation: UIImage.Orientation, username: String?, password: String?, completion: @escaping (UIImage?, [String : Any]?) -> ()) {
        let streamingController = MjpegStreamingController()

        if let username = username, let password = password {
            // User authentication credentials if configured for the printer
            streamingController.authenticationHandler = { challenge in
                let credential = URLCredential(user: username, password: password, persistence: .forSession)
                return (.useCredential, credential)
            }
        }
        
        streamingController.authenticationFailedHandler = {
            let message = NSLocalizedString("Authentication failed", comment: "HTTP authentication failed")
            completion(nil, ["error": message])
        }

        streamingController.didFinishWithErrors = { error in
            completion(nil, ["error": error.localizedDescription])
        }
        
        streamingController.didFinishWithHTTPErrors = { httpResponse in
            // We got a 404 or some 5XX error
            let message = String(format: NSLocalizedString("HTTP Request error", comment: "HTTP Request error info"), httpResponse.statusCode)
            completion(nil, ["error": message])
        }

        streamingController.didRenderImage = { (image: UIImage) in
            // Stop loading next jpeg image (MJPEG is a stream of jpegs)
            streamingController.stop()
            completion(image, nil)
        }

        streamingController.imageOrientation = imageOrientation
        // Get first image and then stop streaming next images
        streamingController.play(url: cameraURL)
    }
    
    fileprivate func renderHLSImage(cameraURL: URL, imageOrientation: UIImage.Orientation, username: String?, password: String?, completion: @escaping (UIImage?, [String : Any]?) -> ()) {
        hlsThumbnailGenerator = HLSThumbnailUtil(url: cameraURL, imageOrientation: imageOrientation, username: username, password: password) { (image: UIImage?) in
            if let image = image {
                // Execute completion block when done
                completion(image, nil)
            } else {
                // Execute completion block when done
                completion(nil, ["error": "No thumbnail generated"])
            }
        }
        hlsThumbnailGenerator!.generate()
    }
    
    fileprivate func getSession() -> WCSession? {
        if let session = session {
            // Check that Apple Watch is paired and app is installed
            if !session.isPaired {
                print("Apple Watch is not paired")
            } else if !session.isWatchAppInstalled {
                print("WatchKit app is not installed")
            } else {
                return session
            }
        }
        return nil
    }
    
    fileprivate func restClientToPrinter(printerName: String) -> (restClient: OctoPrintRESTClient?, sharedNozzle: Bool, palette2PluginInstalled: Bool) {
        var restClient: OctoPrintRESTClient?
        var sharedNozzle = false
        var palette2PluginInstalled = false
        if let printer = printerManager.getDefaultPrinter() {
            if printer.name == printerName && octoprintClient.octoPrintRESTClient.isConfigured() {
                restClient = octoprintClient.octoPrintRESTClient
                sharedNozzle = printer.sharedNozzle
                palette2PluginInstalled = printer.palette2Installed
            }
        }
        if restClient == nil {
            if let printer = printerManager.getPrinterByName(name: printerName) {
                restClient = OctoPrintRESTClient()
                restClient?.connectToServer(serverURL: printer.hostname, apiKey: printer.apiKey, username: printer.username, password: printer.password)
                sharedNozzle = printer.sharedNozzle
                palette2PluginInstalled = printer.palette2Installed
            }
        }
        return (restClient, sharedNozzle, palette2PluginInstalled)

    }
    
    fileprivate func ensureDefaultPrinter(printerName: String) {
        if let printer = printerManager.getDefaultPrinter() {
            if printer.name != printerName {
                // Default printer in the iOS app and Apple Watch is out of sync, let's fix it
                changeDefaultPrinter(printerName: printerName)
            }
        }
    }
    
    fileprivate func encodePrinters() -> [String: [[String : Any]]] {
        var printers: [[String : Any]] = []
        for printer in printerManager.getPrinters() {
            var printerDic = ["position": printer.position, "name": printer.name, "hostname": printer.hostname, "apiKey": printer.apiKey, "isDefault": printer.defaultPrinter] as [String : Any]
            if let username = printer.username {
                printerDic["username"] = username
            }
            if let password = printer.password {
                printerDic["password"] = password
            }
            if let cameras = printer.getMultiCameras(), !cameras.isEmpty {
                // MultiCam plugin is installed so show all cameras
                var camerasArray: Array<Dictionary<String, Any>> = []
                for multiCamera in cameras {
                    var cameraURL: String
                    var cameraOrientation: Int
                    let url = multiCamera.cameraURL
                    if url == printer.getStreamPath() {
                        // This is camera hosted by OctoPrint so respect orientation
                        cameraURL = octoPrintCameraAbsoluteUrl(hostname: printer.hostname, streamUrl: url)
                        cameraOrientation = Int(printer.cameraOrientation)
                    } else {
                        if url.starts(with: "/") {
                            // Another camera hosted by OctoPrint so build absolute URL
                            cameraURL = octoPrintCameraAbsoluteUrl(hostname: printer.hostname, streamUrl: url)
                        } else {
                            // Use absolute URL to render camera
                            cameraURL = url
                        }
                        cameraOrientation = Int(multiCamera.cameraOrientation) // Respect orientation defined by MultiCamera plugin
                    }
                    let cameraDic = ["url" : cameraURL, "orientation": cameraOrientation] as [String : Any]                    
                    camerasArray.append(cameraDic)
                }
                printerDic["cameras"] = camerasArray
            } else {
                // MultiCam plugin is not installed so just show default camera
                let cameraURL = octoPrintCameraAbsoluteUrl(hostname: printer.hostname, streamUrl: printer.getStreamPath())
                let cameraOrientation = Int(printer.cameraOrientation)
                let cameraDic = ["url" : cameraURL, "orientation": cameraOrientation] as [String : Any]
                printerDic["cameras"] = [cameraDic]
            }
            printers.append(printerDic)
        }
//        NSLog("Encoded printers: \(["printers" : printers])")
        
        return ["printers" : printers]
    }
    
    fileprivate func octoPrintCameraAbsoluteUrl(hostname: String, streamUrl: String) -> String {
        if streamUrl.isEmpty {
            // Should never happen but let's be cautious
            return hostname
        }
        if streamUrl.starts(with: "/") {
            // Build absolute URL from relative URL
            return hostname + streamUrl
        }
        // streamURL is an absolute URL so return it
        return streamUrl
    }
}
