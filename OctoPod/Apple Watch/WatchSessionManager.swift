import Foundation
import UIKit
import WatchConnectivity

class WatchSessionManager: NSObject, WCSessionDelegate, CloudKitPrinterDelegate, OctoPrintSettingsDelegate {

    var printerManager: PrinterManager
    var octoprintClient: OctoPrintClient
    var session: WCSession?
    
    var delegates: Array<WatchSessionManagerDelegate> = []

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
    
    // MARK: - Push printers to Apple Watch

    func pushPrinters() {
        do {
            try getSession()?.updateApplicationContext(encodePrinters())
        }
        catch {
            NSLog("Failed to push printers as ApplicationContext. Error: \(error)")
        }
    }
    
    func updateComplications(printerName: String, printerState: String, completion: Double?) {
        if let session = getSession(), session.activationState == .activated {
            let info = ["printer": printerName, "state": printerState, "completion": completion ?? 0.0] as [String : Any]
            let complicationRequest = ["complications" : info]
            if session.isComplicationEnabled {
                if session.remainingComplicationUserInfoTransfers > 0 {
                    // We can update complications using high priority #transferCurrentComplicationUserInfo
                    session.transferCurrentComplicationUserInfo(complicationRequest)
                } else {
                    NSLog("Out of budget so updating complications via #updateApplicationContext")
                    // We are out of budget so attempt updating complications this other way
                    do {
                        try session.updateApplicationContext(complicationRequest)
                    }
                    catch {
                        NSLog("Failed to request WatchOS app to update context \(complicationRequest). Error: \(error)")
                    }
                }
            } else {
                NSLog("Complication not installed on Apple Watch")
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
        var restClient: OctoPrintRESTClient?
        var sharedNozzle: Bool!
        if let printer = printerManager.getDefaultPrinter() {
            if printer.name == printerName {
                restClient = octoprintClient.octoPrintRESTClient
                sharedNozzle = printer.sharedNozzle
            }
        }
        if restClient == nil {
            if let printer = printerManager.getPrinterByName(name: printerName) {
                restClient = OctoPrintRESTClient()
                restClient?.connectToServer(serverURL: printer.hostname, apiKey: printer.apiKey, username: printer.username, password: printer.password)
                sharedNozzle = printer.sharedNozzle
            } else {
                replyHandler(["error": NSLocalizedString("No printer", comment: "")])
                return
            }
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
                    // Send reply back to Apple Watch with results
                    replyHandler(reply)
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
            let streamingController = MjpegStreamingController()
            let screenWidth = camera["width"] as! Int

            if let username = camera["username"] as? String, let password = camera["password"] as? String {
                // User authentication credentials if configured for the printer
                streamingController.authenticationHandler = { challenge in
                    let credential = URLCredential(user: username, password: password, persistence: .forSession)
                    return (.useCredential, credential)
                }
            }
            
            streamingController.authenticationFailedHandler = {
                let message = NSLocalizedString("Authentication failed", comment: "HTTP authentication failed")
                replyHandler(["error": message])
            }

            streamingController.didFinishWithErrors = { error in
                replyHandler(["error": error.localizedDescription])
            }
            
            streamingController.didFinishWithHTTPErrors = { httpResponse in
                // We got a 404 or some 5XX error
                let message = String(format: NSLocalizedString("HTTP Request error", comment: "HTTP Request error info"), httpResponse.statusCode)
                replyHandler(["error": message])
            }

            streamingController.didRenderImage = { (image: UIImage) in
                // Stop loading next jpeg image (MJPEG is a stream of jpegs)
                streamingController.stop()
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
            }

            if let cameraURL = URL(string: url) {
                if let orientation = camera["orientation"] as? Int {
                    streamingController.imageOrientation = UIImage.Orientation(rawValue: orientation)!
                }
                // Get first image and then stop streaming next images
                streamingController.play(url: cameraURL)
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
            if let cameras = printer.cameras, !cameras.isEmpty {
                // MultiCam plugin is installed so show all cameras
                var camerasArray: Array<Dictionary<String, Any>> = []
                for url in cameras {
                    var cameraURL: String
                    var cameraOrientation: Int
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
                        cameraOrientation = UIImage.Orientation.up.rawValue // MultiCam has no information about orientation of extra cameras so assume "normal" position - no flips
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
