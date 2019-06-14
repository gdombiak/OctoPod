import Foundation
import UserNotifications

protocol AbstractNotificationsHandler {
    
    func createNotification(printerName: String) -> UNMutableNotificationContent
    func sendNotification(content: UNMutableNotificationContent)
}

extension AbstractNotificationsHandler {

    func createNotification(printerName: String) -> UNMutableNotificationContent {
        // Create Local Notification's Content
        let content = UNMutableNotificationContent()
        content.sound = UNNotificationSound.default
        content.title = printerName
        // UNUserNotificationCenterDelegate will use the userInfo when the user clicked on the notification
        content.userInfo = ["printerName": printerName]
        return content
    }
    
    func sendNotification(content: UNMutableNotificationContent) {
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
    }
}
