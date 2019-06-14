import Foundation
import UIKit
import UserNotifications

class BedNotificationsHandler: AbstractNotificationsHandler {
    let printerManager: PrinterManager!

    init(printerManager: PrinterManager) {
        self.printerManager = printerManager
    }
    
    func receivedNotification(printerID: String, event: String, temperature: Double, bedMinutes: Int?, completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if let idURL = URL(string: printerID), let printer = printerManager.getPrinterByObjectURL(url: idURL) {
            
            // Create Local Notification's Content
            let content = createNotification(printerName: printer.name)
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
            
            // Send local notification
            sendNotification(content: content)

            completionHandler(.newData)
        } else {
            // Unkown ID of printer
            completionHandler(.noData)
        }
    }
}
