import Foundation
import UIKit
import UserNotifications

class MMUNotificationsHandler: AbstractNotificationsHandler {
    let printerManager: PrinterManager!
    
    var snoozePrinters: [String: TimeInterval] = [:]
    
    init(printerManager: PrinterManager) {
        self.printerManager = printerManager
    }

    func receivedNotification(printerID: String, event: String, completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if let idURL = URL(string: printerID), let printer = printerManager.getPrinterByObjectURL(url: idURL) {
            // Check if snooze for the specified printer is active
            if let expirationDateTime = snoozePrinters[printer.name] {
                if Date().timeIntervalSinceReferenceDate < expirationDateTime {
                    completionHandler(.newData)
                    return
                }
            }
            
            // Create Local Notification's Content
            let content = createNotification(printerName: printer.name)
            content.body = NSString.localizedUserNotificationString(forKey: "MMU Requires User", arguments: nil)
            content.categoryIdentifier = NotificationsManager.mmuSnoozeCategory  // Use MMU category so snooze action buttons are available
            
            // Send local notification
            sendNotification(content: content)

            completionHandler(.newData)
        } else {
            // Unkown ID of printer
            completionHandler(.noData)
        }
    }
    
    // Stop sending MMU alerts for the specified printer for the specified amount of hours
    func snoozeNotifications(printerName: String, hours: Int) {
        let seconds = hours * 60 // * 60
        snoozePrinters[printerName] = Date().timeIntervalSinceReferenceDate + Double(seconds)
    }
}
