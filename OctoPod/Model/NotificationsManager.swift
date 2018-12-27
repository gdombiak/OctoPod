import Foundation
import UIKit
import UserNotifications

class NotificationsManager: NSObject, OctoPrintSettingsDelegate, UNUserNotificationCenterDelegate {
    
    private let printerManager: PrinterManager!
    private let octoprintClient: OctoPrintClient!
    private let watchSessionManager: WatchSessionManager!
    
    private var currentToken: String?

    init(printerManager: PrinterManager, octoprintClient: OctoPrintClient, watchSessionManager: WatchSessionManager) {
        self.printerManager = printerManager
        self.octoprintClient = octoprintClient
        self.watchSessionManager = watchSessionManager
        
        super.init()

        // Listen to changes to OctoPrint Settings in case the camera orientation has changed
        octoprintClient.octoPrintSettingsDelegates.append(self)
        
        UNUserNotificationCenter.current().delegate = self
    }

    // Register the specified token with all OctoPrints that have the OctoPod Plugin installed
    // so that push notifications can be sent
    // The specified token is not necessarily new
    func registerToken(token: String) {
        // Remember current APNS token that was given to the app
        currentToken = token
        
        for printer in printerManager.getPrinters() {
            if printer.octopodPluginInstalled && printer.notificationToken != token {
                // Update APNS token in this OctoPrint instance
                updateNotificationToken(printer: printer)
            }
        }
    }
    
    // MARK: - OctoPrintSettingsDelegate

    func octoPodPluginChanged(installed: Bool) {
        if let printer = printerManager.getDefaultPrinter() {
            if installed {
                // Update APNS token in this OctoPrint instance
                updateNotificationToken(printer: printer)
            }
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // User clicked on notification that job is done. Let's switch to the selected printer
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if let printerName = response.notification.request.content.userInfo["printerName"] as? String {
            if let printer = printerManager.getPrinterByName(name: printerName) {
                printerManager.changeToDefaultPrinter(printer)

                // Ask octoprintClient to connect to new OctoPrint server
                octoprintClient.connectToServer(printer: printer)
                // Notify listeners of this change
                for delegate in watchSessionManager.delegates {
                    delegate.defaultPrinterChanged()
                }

                // Update Apple Watch with new selected printer
                watchSessionManager.pushPrinters()
            }
        }
        completionHandler()
    }

    // MARK: - Private functions
    
    fileprivate func updateNotificationToken(printer: Printer) {
        if let newToken = currentToken {
            let deviceName = UIDevice.current.name
            let id = printer.objectID.uriRepresentation().absoluteString
            octoprintClient.registerAPNSToken(oldToken: printer.notificationToken, newToken: newToken, deviceName: deviceName, printerID: id) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                if requested {
                    let newObjectContext = self.printerManager.newPrivateContext()
                    let printerToUpdate = newObjectContext.object(with: printer.objectID) as! Printer
                    // Update flag that tracks if OctoPod plugin is installed
                    printerToUpdate.notificationToken = newToken
                    // Persist updated printer
                    self.printerManager.updatePrinter(printerToUpdate, context: newObjectContext)
                } else {
                    if let error = error {
                        NSLog("Failed to register new APNS token with OctoPrint. Error: \(error.localizedDescription). Response: \(response)")
                    } else {
                        NSLog("Failed to register new APNS token with OctoPrint. Response: \(response)")
                    }
                }
            }
        }
    }
}
