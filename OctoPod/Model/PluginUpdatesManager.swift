//import CommonCrypto
import Foundation

class PluginUpdatesManager {
    
    struct UpdateAvailable: Comparable {
        var pluginName: String
        var version: String

        static func <(lhs: UpdateAvailable, rhs: UpdateAvailable) -> Bool {
            return lhs.pluginName < rhs.pluginName
        }
    }
    
    private let printerManager: PrinterManager!
    private let octoprintClient: OctoPrintClient!
    private let appConfiguration: AppConfiguration!
    
    init(printerManager: PrinterManager, octoprintClient: OctoPrintClient, appConfiguration: AppConfiguration) {
        self.printerManager = printerManager
        self.octoprintClient = octoprintClient
        self.appConfiguration = appConfiguration
    }
    
    func checkUpdatesFor(printer: Printer, callback: @escaping (_ error: Error?, _ response: HTTPURLResponse, _ updatesAvailable: Array<UpdateAvailable>?) -> Void) {
        var pluginsUpdateNextCheck: Date?, pluginsUpdateSnooze: String?, hostname: String!
        let newObjectContext = printerManager.safePrivateContext()
        newObjectContext.performAndWait {
            let printerToRead = newObjectContext.object(with: printer.objectID) as! Printer
            pluginsUpdateNextCheck = printerToRead.pluginsUpdateNextCheck
            pluginsUpdateSnooze = printerToRead.pluginsUpdateSnooze
            hostname = printerToRead.hostname
        }
        if pluginsUpdateNextCheck == nil || pluginsUpdateNextCheck! <= Date() {
            octoprintClient.checkPluginUpdates { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                if response.statusCode == 200 {
                    // Update next time we should check again for plugin updates
                    self.saveNextCheck(printer: printer)
                    
                    // Check that there are updates available
                    if let json = result as? NSDictionary {
                        if let status = json["status"] as? String, status == "current" {
                            // No updates available
                            callback(nil, response, Array())
                            return
                        }
                        // Build array of available updates
                        let updatesAvailable = self.readUpdatesAvailable(json: json)
                        // Calculate snooze string
                        let snoozeHash = self.snoozeString(updatesAvailable: updatesAvailable)
                        // Check if user requested to snooze previously detected updates
                        if pluginsUpdateSnooze == snoozeHash {
                            // User elected to ignore this update. Return 200 response
                            callback(nil, response, nil)
                            return
                        }
                        // Notify user that plugin updates are available
                        callback(nil, response, updatesAvailable)
                    }
                } else {
                    NSLog("Error checking for plugin updates. Response: \(response)")
                    callback(error, response, nil)
                }
            }
        } else {
            // No HTTP request was made. Return a fake 304 response
            returnNothingChanged(hostname: hostname, callback: callback)
        }
    }
    
    func snoozeUpdatesFor(printer: Printer, updatesAvailable: Array<UpdateAvailable>) {
        // Calculate snooze string
        let snoozeHash = self.snoozeString(updatesAvailable: updatesAvailable)

        let newObjectContext = printerManager.safePrivateContext()
        newObjectContext.performAndWait {
            // Update printer with calculated snooze hash
            let printerToUpdate = newObjectContext.object(with: printer.objectID) as! Printer
            // Update hash that identifies available plugins that user wants to ignore
            printerToUpdate.pluginsUpdateSnooze = snoozeHash
            // Persist updated printer
            self.printerManager.updatePrinter(printerToUpdate, context: newObjectContext)
        }
    }
    
    // MARK: - Private functions
    
    fileprivate func saveNextCheck(printer: Printer) {
        let newDate = Calendar.current.date(byAdding: .hour, value: appConfiguration.pluginUpdatesCheckFrequency(), to: Date())
        
        let newObjectContext = printerManager.safePrivateContext()
        newObjectContext.performAndWait {
            let printerToUpdate = newObjectContext.object(with: printer.objectID) as! Printer
            // Update date when we need to check for plugin updates for this OctoPrint instance
            printerToUpdate.pluginsUpdateNextCheck = newDate
            // Persist updated printer
            printerManager.updatePrinter(printerToUpdate, context: newObjectContext)
        }
    }
    
    fileprivate func readUpdatesAvailable(json: NSDictionary) -> Array<UpdateAvailable> {
        var updatesAvailable = Array<UpdateAvailable>()
        if let info = json["information"] as? Dictionary<String, NSDictionary> {
            for plugin in info.values {
                if let displayName = plugin["displayName"] as? String, let pluginInfo = plugin["information"] as? NSDictionary, let remote = pluginInfo["remote"] as? NSDictionary, let displayVersion = remote["name"] as? String, let updateAvailable = plugin["updateAvailable"] as? Bool {
                    if updateAvailable {
                        updatesAvailable.append(UpdateAvailable(pluginName: displayName, version: displayVersion))
                    }
                }
            }
        }
        return updatesAvailable
    }
    
    fileprivate func snoozeString(updatesAvailable: Array<UpdateAvailable>) -> String {
        var combined = ""
        for updateAvailable in updatesAvailable.sorted() {
//            NSLog("Hashing \(updateAvailable.pluginName) - \(updateAvailable.version)")
            combined = combined + updateAvailable.pluginName + updateAvailable.version
        }
//        NSLog("Hash for \(updatesAvailable.count) updates is \(combined.djb2hash)")
        return "\(combined.djb2hash)"
    }
    
    fileprivate func returnNothingChanged(hostname: String, callback: @escaping (_ error: Error?, _ response: HTTPURLResponse, _ updatesAvailable: Array<UpdateAvailable>?) -> Void) {
        // Simulate that we made the request and nothing changed
        if let url = URL(string: hostname + "/plugin/softwareupdate/check"), let response = HTTPURLResponse(url: url, statusCode: 304, httpVersion: nil, headerFields: nil) {
            callback(nil, response, nil)
        }
    }
}

extension String {
    var djb2hash: Int {
        let unicodeScalars = self.unicodeScalars.map { $0.value }
        return unicodeScalars.reduce(5381) {
            ($0 << 5) &+ $0 &+ Int($1)
        }
    }
}

//extension String {
//    func sha1() -> String {
//        let data = Data(self.utf8)
//        var digest = [UInt8](repeating: 0, count:Int(CC_SHA1_DIGEST_LENGTH))
//        data.withUnsafeBytes {
//            _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &digest)
//        }
//        let hexBytes = digest.map { String(format: "%02hhx", $0) }
//        return hexBytes.joined()
//    }
//}
