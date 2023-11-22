import Foundation
import UIKit
import UserNotifications

class NotificationsManager: NSObject, OctoPrintSettingsDelegate, UNUserNotificationCenterDelegate {
    
    static let mmuSnoozeCategory = "mmuSnoozeActions"
    private let mmuSnooze1Identifier = "mmuSnooze1"
    private let mmuSnooze8Identifier = "mmuSnooze8"

    static let printCompleteCategory = "printComplete"
    private let printAgainIdentifier = "printAgain"

    private let printerManager: PrinterManager!
    private let octoprintClient: OctoPrintClient!
    private let defaultPrinterManager: DefaultPrinterManager!
    private let mmuNotificationsHandler: MMUNotificationsHandler!
    
    private var currentToken: String?

    init(printerManager: PrinterManager, octoprintClient: OctoPrintClient, defaultPrinterManager: DefaultPrinterManager, mmuNotificationsHandler: MMUNotificationsHandler) {
        self.printerManager = printerManager
        self.octoprintClient = octoprintClient
        self.defaultPrinterManager = defaultPrinterManager
        self.mmuNotificationsHandler = mmuNotificationsHandler
        
        super.init()

        // Listen to changes to OctoPrint Settings in case the camera orientation has changed
        octoprintClient.octoPrintSettingsDelegates.append(self)
        
        UNUserNotificationCenter.current().delegate = self
        
        // Create action for snooze button
        let snooze1Action = UNNotificationAction(identifier: mmuSnooze1Identifier, title: NSLocalizedString("Snooze 1 hour", comment: "Snooze notifications for 1 hour"),options:[])
        let snooze8Action = UNNotificationAction(identifier: mmuSnooze8Identifier, title: NSLocalizedString("Snooze 8 hours", comment: "Snooze notifications for 8 hours"),options:[])
        
        // Create category that will include snooze action
        let mmuCategory = UNNotificationCategory(identifier: NotificationsManager.mmuSnoozeCategory, actions: [snooze1Action, snooze8Action], intentIdentifiers: [], options: [])

        // Create action for print again button
        let printAgainAction = UNNotificationAction(identifier: printAgainIdentifier, title: NSLocalizedString("Print Again", comment: ""),options:[])
        
        // Create category that will include print again
        let printCompletedCategory = UNNotificationCategory(identifier: NotificationsManager.printCompleteCategory, actions: [printAgainAction], intentIdentifiers: [], options: [])

        UNUserNotificationCenter.current().setNotificationCategories([mmuCategory, printCompletedCategory])
    }

    // Register the specified token with all OctoPrints that have the OctoPod Plugin installed
    // so that push notifications can be sent
    // The specified token is not necessarily new
    func registerToken(token: String) {
        // Remember current APNS token that was given to the app
        currentToken = token
        let languageCode = appLanguageCode()

        for printer in printerManager.getPrinters() {
            if printer.octopodPluginInstalled && (printer.notificationToken != token || printer.octopodPluginPrinterName != printer.name || printer.octopodPluginLanguage != languageCode) {
                // Update APNS token in this OctoPrint instance
                updateNotificationToken(printer: printer)
            }
        }
    }
    
    // MARK: - Notifications

    /**
     Notification that user has changed named of the specified printer. If OctoPrint instance has
     OctoPod plugin installed then we need to refresh the printer name information in the plugin so
     future notifications display the proper printer name and when user clicks on the notification we
     can switch to the selected printer
     - parameter printer: the printer whose name has been modified. It may or may not have OctoPod plugin installed
     */
    func printerNameChanged(printer: Printer) {
        if printer.octopodPluginInstalled {
            // Update APNS token and printer name of the modified printer
            updateNotificationToken(printer: printer)
        }
    }
    
    /**
     User selected a new language for the app. We need to refresh OctoPod plugins for all connected OctoPrint instances
     to use the new languge. Changes to iOS languages are not going to force a refresh in the plugin. That case is
     not supported yet.
    */
    func userChangedLanguage() {
        for printer in printerManager.getPrinters() {
            if printer.octopodPluginInstalled {
                // Update language stored in OctoPod plugin
                updateNotificationToken(printer: printer)
            }
        }
    }
    
    // MARK: - OctoPrintSettingsDelegate

    func octoPodPluginChanged(installed: Bool) {
        if let printer = printerManager.getDefaultPrinter(context: printerManager.safePrivateContext()) {
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
                if let printer = printerManager.getPrinterByName(name: printerName), let _ = printer.octopodPluginPrinterName {
                    // OctoPod plugin handles non-silent notifications so snooze is done in OctoPrint's server
                    defaultPrinterManager.changeToDefaultPrinter(printer: printer, updateWatch: false, connect: true)
                    // Request OctoPod plugin to snooze MMU events
                    octoprintClient.snoozeAPNSEvents(eventCode: "mmu-event", minutes: response.actionIdentifier == mmuSnooze1Identifier ? 60 : 480) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                        if !requested {
                            NSLog("Failed to request snooze of MMU events. Response: \(response)")
                        }
                        // Execute completion handler in main thread
                        DispatchQueue.main.async {
                            completionHandler()
                        }
                    }

                } else {
                    // OctoPod plugin is not updated so app is using silent notifications. Snooze is handled by the app in this legacy mode
                    mmuNotificationsHandler.snoozeNotifications(printerName: printerName, hours: response.actionIdentifier == mmuSnooze1Identifier ? 1 : 8)
                    // Execute completion handler
                    completionHandler()
                }
            } else if response.actionIdentifier == printAgainIdentifier {
                // Request OctoPrint to print again last completed print
                if let printer = printerManager.getPrinterByName(name: printerName), let fileOrigin = response.notification.request.content.userInfo["file-origin"] as? String, let filePath = response.notification.request.content.userInfo["file-path"] as? String {
                    // Let's switch to the selected printer
                    defaultPrinterManager.changeToDefaultPrinter(printer: printer, updateWatch: false, connect: true)
                    // Request OctoPrint to print again last printed file
                    octoprintClient.printFile(origin: fileOrigin, path: filePath) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                        if !requested {
                            NSLog("Failed to request to print again selected file. Response: \(response)")
                        }
                        // Execute completion handler in main thread
                        DispatchQueue.main.async {
                            completionHandler()
                        }
                    }
                } else {
                    // Execute completion handler
                    completionHandler()
                }
            } else if let printer = printerManager.getPrinterByName(name: printerName) {
                // User clicked on notification. Let's switch to the selected printer
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    self.defaultPrinterManager.changeToDefaultPrinter(printer: printer)
                    // Execute completion handler
                    completionHandler()
                }
            }
        } else {
            // Execute completion handler
            completionHandler()
        }
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
            let languageCode = appLanguageCode()
            let restClient = OctoPrintRESTClient()

            let newObjectContext = self.printerManager.safePrivateContext()
            newObjectContext.performAndWait {
                let printerToUpdate = newObjectContext.object(with: printer.objectID) as! Printer
                
                restClient.connectToServer(serverURL: printerToUpdate.hostname, apiKey: printerToUpdate.apiKey, username: printerToUpdate.username, password: printerToUpdate.password, headers: printerToUpdate.headers, preemptive: printerToUpdate.preemptiveAuthentication())
                restClient.registerAPNSToken(oldToken: printerToUpdate.notificationToken, newToken: newToken, deviceName: deviceName, printerID: id, printerName: printerToUpdate.name, languageCode: languageCode) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                    if requested {
                        let newObjectContext = self.printerManager.newPrivateContext()
                        newObjectContext.performAndWait {
                            let printerToUpdate = newObjectContext.object(with: printer.objectID) as! Printer
                            // Update flag that tracks if OctoPod plugin is installed
                            printerToUpdate.notificationToken = newToken
                            printerToUpdate.octopodPluginPrinterName = printerToUpdate.name
                            printerToUpdate.octopodPluginLanguage = languageCode
                            // Persist updated printer
                            self.printerManager.updatePrinter(printerToUpdate, context: newObjectContext)
                        }
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
    
    fileprivate func appLanguageCode() -> String {
        var languageCode = Locale.current.languageCode ?? "en"
        if let override = UserDefaults.standard.string(forKey: ChangeLanguageViewController.CHANGE_LANGUAGE_OVERRIDE) {
            languageCode = override
        }
        return languageCode
    }
}
