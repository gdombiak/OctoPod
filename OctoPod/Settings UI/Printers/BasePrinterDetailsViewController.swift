import UIKit

class BasePrinterDetailsViewController: ThemedStaticUITableViewController {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()
    let cloudKitPrinterManager: CloudKitPrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).cloudKitPrinterManager }()
    let watchSessionManager: WatchSessionManager = { return (UIApplication.shared.delegate as! AppDelegate).watchSessionManager }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    let notificationsManager: NotificationsManager = { return (UIApplication.shared.delegate as! AppDelegate).notificationsManager }()

    var newPrinterPosition: Int16!  // Will have a value only when adding a new printer

    func createPrinter(connectionType: PrinterConnectionType, name: String, hostname: String, apiKey: String, username: String?, password: String?, position: Int16, includeInDashboard: Bool, showCamera: Bool) {
        if printerManager.addPrinter(connectionType: connectionType, name: name, hostname: hostname, apiKey: apiKey, username: username, password: password, position: position, iCloudUpdate: true) {
            if let printer = printerManager.getPrinterByName(name: name) {
                // Only update printer if dashboard configuration needs update
                if printer.includeInDashboard != includeInDashboard || printer.hideCamera == showCamera {
                    let newObjectContext = printerManager.newPrivateContext()
                    let printerToUpdate = newObjectContext.object(with: printer.objectID) as! Printer
                    // Update flag that tracks if printer should be displayed in dashboard
                    printerToUpdate.includeInDashboard = includeInDashboard
                    // Update flag that tracks if camera subpanel will be displayed for this printer
                    printerToUpdate.hideCamera = !showCamera
                    // Persist updated printer
                    printerManager.updatePrinter(printerToUpdate, context: newObjectContext)
                }
                // Create Siri suggestions (user will need to manually delete recorded Shortcuts)
                IntentsDonations.donatePrinterIntents(printer: printer)
            } else {
                NSLog("Missing newly added printer: \(name)")
            }
            // Push changes to iCloud so other devices of the user get updated (only if iCloud enabled and user is logged in)
            cloudKitPrinterManager.pushChanges(completion: nil)
            // Push changes to Apple Watch
            watchSessionManager.pushPrinters()
        }
    }
    
    func updatePrinter(printer: Printer, name: String, hostname: String, apiKey: String, username: String?, password: String?, includeInDashboard: Bool, showCamera: Bool) {
        let nameChanged = printer.name != name
        // Update existing printer
        printer.name = name
        printer.hostname = hostname
        printer.apiKey = apiKey
        printer.userModified = Date() // Track when settings were modified
        
        printer.username = username
        printer.password = password
        
        printer.includeInDashboard = includeInDashboard
        printer.hideCamera = !showCamera
        
        // Mark that iCloud needs to be updated
        printer.iCloudUpdate = true
        
        printerManager.updatePrinter(printer)
        
        // If default printer was edited then we need to update connections to use new settings
        if printer.defaultPrinter {
            octoprintClient.connectToServer(printer: printer)
        }
        // Recreate Siri suggestions (user will need to manually delete recorded Shortcuts)
        IntentsDonations.deletePrinterIntents(printer: printer)
        IntentsDonations.donatePrinterIntents(printer: printer)
        
        if nameChanged {
            notificationsManager.printerNameChanged(printer: printer)
        }

        // Push changes to iCloud so other devices of the user get updated (only if iCloud enabled and user is logged in)
        cloudKitPrinterManager.pushChanges(completion: nil)
        // Push changes to Apple Watch
        watchSessionManager.pushPrinters()
    }

    func goBack() {
        // Go back to previous page and execute the unwinsScanQRCode IBAction
        performSegue(withIdentifier: "unwindPrintersUpdated", sender: self)
    }
}
