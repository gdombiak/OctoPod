import Foundation

class OctoPrintClient {
    
    static let instance = OctoPrintClient()
    
    var octoPrintRESTClient: OctoPrintRESTClient?  // Used in case iOS app is not reachable so Apple Watch with Wifi or LTE can still function (though slower)
    
    func configure() {
        if let printer = PrinterManager.instance.defaultPrinter() {
            octoPrintRESTClient = OctoPrintRESTClient()
            octoPrintRESTClient?.connectToServer(serverURL: PrinterManager.instance.hostname(printer: printer), apiKey: PrinterManager.instance.apiKey(printer: printer), username: PrinterManager.instance.username(printer: printer), password: PrinterManager.instance.password(printer: printer))
        } else {
            octoPrintRESTClient = nil
        }
    }
    
    // MARK: - Printer operations
    
    // Retrieves the current state of the printer. Returned information includes:
    // 1. temperature information (see also Retrieve the current tool state and Retrieve the current bed state)
    // 2. sd state (if available, see also Retrieve the current SD state)
    // 3. general printer state
    func printerState(callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient?.printerState(callback: callback)
    }

    // MARK: - Job operations
    
    func currentJobInfo(callback: @escaping ([String : Any]) -> Void) {
        let restCallback = { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
            if let error = error {
                callback(["error": error.localizedDescription])
            } else if let result = result as? Dictionary<String, Any> {
                var dict: [String : Any] = [:]
                if let state = result["state"] as? String {
                    dict["state"] = state
                }
                if let progress = result["progress"] as? Dictionary<String, Any> {
                    if let completion = progress["completion"] as? Double {
                        dict["completion"] = completion
                    }
                    if let printTimeLeft = progress["printTimeLeft"] as? Int {
                        dict["printTimeLeft"] = printTimeLeft
                    }
                }
                callback(dict)
            }
        }
        if let session = WatchSessionManager.instance.session {
            session.sendMessage(["panel_info" : ""], replyHandler: { (reply: [String : Any]) in
                callback(reply)
            }) { (error: Error) in
                NSLog("Error asking 'panel_info' with Watch Connectivity Framework. Error: \(error)")
                // Try making HTTP request instead of using Watch Connectivity Framework that uses the iOS app
                self.octoPrintRESTClient?.currentJobInfo(callback: restCallback)
            }
        } else {
            NSLog("Using fallback for 'panel_info' since Watch Connectivity Framework is not available.")
            // Try making HTTP request instead of using Watch Connectivity Framework that uses the iOS app
            octoPrintRESTClient?.currentJobInfo(callback: restCallback)
        }
    }
}
