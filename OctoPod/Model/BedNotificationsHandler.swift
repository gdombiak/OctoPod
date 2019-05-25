import Foundation
import UIKit
import UserNotifications

class BedNotificationsHandler {
    let printerManager: PrinterManager!

    init(printerManager: PrinterManager) {
        self.printerManager = printerManager
    }
    
    func receivedBedNotification(printerID: String, event: String, temperature: Double, bedMinutes: Int?, completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if let idURL = URL(string: printerID), let printer = printerManager.getPrinterByObjectURL(url: idURL) {
            let printerName = printer.name
            // Create Local Notification's Content
            let content = UNMutableNotificationContent()
            content.title = printerName
            if event == "bed-cooled" {
                // Not passing temperature as parameter due to error (seems arguments needs to be [] of CVarArg
                content.body = NSString.localizedUserNotificationString(forKey: "Bed cooled", arguments: nil)
            } else if event == "bed-warmed", let _ = bedMinutes {
                // Not passing temperature and bedMinutes as parameters due to error (seems arguments needs to be [] of CVarArg
                content.body = NSString.localizedUserNotificationString(forKey: "Bed warmed", arguments: nil)
            } else {
                NSLog("Ignored unkown bed event: \(event). No local notification was sent")
                completionHandler(.noData)
                return
            }
            // UNUserNotificationCenterDelegate will use the userInfo when the user clicked on the notification
            content.userInfo = ["printerName": printerName]
            
            // Create the request
            let uuidString = UUID().uuidString
            let request = UNNotificationRequest(identifier: uuidString, content: content, trigger: nil)
            
            // Schedule the request with the system.
            let notificationCenter = UNUserNotificationCenter.current()
            notificationCenter.add(request) { (error) in
                if let error = error {
                    NSLog("Error asking iOS to present local notification. Error: \(error)")
                }
            }
            completionHandler(.newData)
        } else {
            // Unkown ID of printer
            completionHandler(.noData)
        }
    }
}
