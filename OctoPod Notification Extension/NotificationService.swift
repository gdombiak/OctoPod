import UserNotifications

/**
 Extension used when OctoPod plugin for OctoPrint sends a push notification that includes an image. This extension will fetch the image and add
 it as an attachment to the received notification. iOS will display the notification including the fetched image.
 */
class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        if let bestAttemptContent = bestAttemptContent {
            // Fetch image from provided URL and add it as an attachment to the notification that iOS will display
            if let url = request.content.userInfo["media-url"] as? String, let fetchURL = URL(string: url) {
                do {
                    let imageData = try Data(contentsOf: fetchURL)
                    if let attachment = self.saveImageToDisk(data: imageData, options: nil) {
                        bestAttemptContent.attachments = [attachment]
                    }
                } catch let error {
                    NSLog("Error fetching image from provided URL: \(error)")
                }
            }
            
            contentHandler(bestAttemptContent)
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    // MARK: - Private functions

    fileprivate func saveImageToDisk(data: Data, options: [NSObject : AnyObject]?) -> UNNotificationAttachment? {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString, isDirectory: true)
        let fileIdentifier = "image.jpg"
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            let fileURL = directory.appendingPathComponent(fileIdentifier)
            try data.write(to: fileURL, options: [])
            return  try UNNotificationAttachment(identifier: fileIdentifier, url: fileURL, options: options)
        } catch let error {
            NSLog("Error creating attachment from image: \(error)")
        }
        
        return nil
    }

}
