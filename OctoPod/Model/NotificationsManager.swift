import Foundation
import UIKit

class NotificationsManager: OctoPrintSettingsDelegate {
    
    private let printerManager: PrinterManager!
    private let octoprintClient: OctoPrintClient!
    
    private var currentToken: String?

    init(printerManager: PrinterManager, octoprintClient: OctoPrintClient) {
        self.printerManager = printerManager
        self.octoprintClient = octoprintClient

        // Listen to changes to OctoPrint Settings in case the camera orientation has changed
        octoprintClient.octoPrintSettingsDelegates.append(self)
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

    // MARK: - Private functions
    
    fileprivate func updateNotificationToken(printer: Printer) {
        if let newToken = currentToken {
            let deviceName = UIDevice.current.name
            octoprintClient.registerAPNSToken(oldToken: printer.notificationToken, newToken: newToken, deviceName: deviceName) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
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
