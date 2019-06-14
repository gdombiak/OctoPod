import Foundation
import UIKit
import UserNotifications

class NotificationsManager: NSObject, OctoPrintSettingsDelegate, UNUserNotificationCenterDelegate {
    
    static let mmuSnoozeCategory = "mmuSnoozeActions"
    private let mmuSnooze1Identifier = "mmuSnooze1"
    private let mmuSnooze8Identifier = "mmuSnooze8"

    private let printerManager: PrinterManager!
    private let octoprintClient: OctoPrintClient!
    private let watchSessionManager: WatchSessionManager!
    private let mmuNotificationsHandler: MMUNotificationsHandler!
    
    private var currentToken: String?

    init(printerManager: PrinterManager, octoprintClient: OctoPrintClient, watchSessionManager: WatchSessionManager, mmuNotificationsHandler: MMUNotificationsHandler) {
        self.printerManager = printerManager
        self.octoprintClient = octoprintClient
        self.watchSessionManager = watchSessionManager
        self.mmuNotificationsHandler = mmuNotificationsHandler
        
        super.init()

        // Listen to changes to OctoPrint Settings in case the camera orientation has changed
        octoprintClient.octoPrintSettingsDelegates.append(self)
        
        UNUserNotificationCenter.current().delegate = self
        
        // Create action for snooze button
        let snooze1Action = UNNotificationAction(identifier: mmuSnooze1Identifier, title: NSLocalizedString("Snooze 1 hour", comment: "Snooze notifications for 1 hour"),options:[])
        let snooze8Action = UNNotificationAction(identifier: mmuSnooze8Identifier, title: NSLocalizedString("Snooze 8 hours", comment: "Snooze notifications for 8 hours"),options:[])
        
        // Create category that will include snooze action
        let category = UNNotificationCategory(identifier: NotificationsManager.mmuSnoozeCategory, actions: [snooze1Action, snooze8Action], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
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
    
    // User clicked on notification or selected an action from notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if let printerName = response.notification.request.content.userInfo["printerName"] as? String {
            if response.actionIdentifier == mmuSnooze1Identifier || response.actionIdentifier == mmuSnooze8Identifier {
                // User selected to snooze MMU notifications for this printer
                mmuNotificationsHandler.snoozeNotifications(printerName: printerName, hours: response.actionIdentifier == mmuSnooze1Identifier ? 1 : 8)
            } else if let printer = printerManager.getPrinterByName(name: printerName) {
                // User clicked on notification. Let's switch to the selected printer
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
    
    // Display notification even if app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler(.alert)
    }

    // MARK: - Private functions
    
    fileprivate func updateNotificationToken(printer: Printer) {
        if let newToken = currentToken {
            let deviceName = UIDevice.current.name
            let id = printer.objectID.uriRepresentation().absoluteString
            let restClient = OctoPrintRESTClient()
            restClient.connectToServer(serverURL: printer.hostname, apiKey: printer.apiKey, username: printer.username, password: printer.password)
            restClient.registerAPNSToken(oldToken: printer.notificationToken, newToken: newToken, deviceName: deviceName, printerID: id) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
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
