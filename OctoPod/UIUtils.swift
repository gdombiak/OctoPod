import Foundation
import UserNotifications
#if canImport(UIKit)
// iOS, tvOS, and watchOS – use UIKit
import UIKit
#else
// all other platforms meaning macOS
import Cocoa
#endif

class UIUtils {
    #if canImport(UIKit)
    // iOS, tvOS, and watchOS – use UIKit
    /// Caller may not be running in Main thread
    static func showAlert(presenter: UIViewController, title: String, message: String, done: (() -> Void)?) {
        // We are not always on the main thread so present dialog on main thread to prevent crashes
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("Dismiss", comment: ""), style: .default, handler: { (UIAlertAction) -> Void in
                // Execute done block on dismiss
                done?()
            }))
            presenter.present(alert, animated: true) { () -> Void in
                // Nothing to do here
            }
        }
    }
    #else
    // all other platforms meaning macOS
    static func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    #endif
    
    #if canImport(UIKit)
    // iOS, tvOS, and watchOS – use UIKit
    /// Caller MUST be running in Main thread
    static func showConfirm(presenter: UIViewController, message: String, yes: @escaping (UIAlertAction) -> Void, no: @escaping (UIAlertAction) -> Void) {
        let alert = UIAlertController(title: NSLocalizedString("Confirm", comment: ""), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Yes", comment: ""), style: .default, handler: yes))
        // Use default style and not cancel style for NO so it appears on the right
        alert.addAction(UIAlertAction(title: NSLocalizedString("No", comment: ""), style: .default, handler: no))
        presenter.present(alert, animated: true) { () -> Void in
            // Nothing to do here
        }
    }
    #else
    // all other platforms meaning macOS
    static func showConfirm(title: String, message: String) -> Bool {
           let alert = NSAlert()
           alert.messageText = title
           alert.informativeText = message
           alert.alertStyle = .warning
           alert.addButton(withTitle: "OK")
           alert.addButton(withTitle: "Cancel")
           return alert.runModal() == .alertFirstButtonReturn
    }
    #endif
    @available(OSX 10.14, *)
    static func notifyUser(title: String, message: String)  {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = "alarm"
        // Configure the recurring date.
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)

        // Create the request
        let uuidString = UUID().uuidString
        let request = UNNotificationRequest(identifier: uuidString,
                    content: content, trigger: trigger)

        // Schedule the request with the system.
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.add(request) { (error) in
           if error != nil {
            print(error.debugDescription)
           }
        }
    }
    
    static func calculateCameraHeightConstraints(screenHeight: CGFloat) -> (cameraHeight4_3ConstraintPortrait: CGFloat, cameraHeight4_3ConstraintLandscape: CGFloat, camera16_9HeightConstraintPortrait: CGFloat, cameral16_9HeightConstraintLandscape: CGFloat){
        if screenHeight <= 568 {
            // iPhone 5, 5s, 5c, SE (and older models)
            return (183, 0, 183, 0)
        } else if screenHeight == 667 {
            // iPhone 6, 6s, 7, 8
            return (281, 0, 211, 0)
        } else if screenHeight == 736 {
            // iPhone 7/8 Plus
            return (311, 0, 233, 0)
        } else if screenHeight == 812 {
            // iPhone X, Xs
            return (281, 0, 211, 0)
        } else if screenHeight == 896 {
            // iPhone Xr, Xs Max
            return (311, 0, 233, 0)
        } else if screenHeight == 1024 {
            // iPad (9.7-inch)
            return (571, 348, 432, 348)
        } else if screenHeight == 1080 {
            // iPad (7th generation) (2019)
            return (608, 414, 457, 414)
        } else if screenHeight == 1112 {
            // iPad (10.5-inch)
            return (619, 414, 469, 414)
        } else if screenHeight == 1194 {
            // iPad Pro (11 inch)
            return (626, 414, 469, 414)
        } else if screenHeight >= 1366 {
            // iPad (12.9-inch)
            return (763, 604, 576, 604)
        } else {
            // Unknown device so use default value
            return (281, 0, 211, 0)
        }
    }
    
    static func dateToString(date: Date?, dateStyle: DateFormatter.Style = .medium, timeStyle: DateFormatter.Style = .medium) -> String {
        if let dateToConvert = date {
            return DateFormatter.localizedString(from: dateToConvert, dateStyle: dateStyle, timeStyle: timeStyle)
        }
        return ""
    }
    
    // Converts number of seconds into a string that represents aproximate time (e.g. About 23h 10m)
    static func secondsToEstimatedPrintTime(seconds: Double?) -> String {
        if seconds == nil || seconds == 0 {
            return ""
        }
        let duration = TimeInterval(Int(seconds!))
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .brief
        formatter.includesApproximationPhrase = true
        formatter.allowedUnits = [ .day, .hour, .minute ]
        return formatter.string(from: duration)!
    }
    
    /// Return estimated time based on number of estimated seconds to completion
    /// - parameter seconds: estimated number of seconds to complection
    static func secondsToTimeLeft(seconds: Int, includesApproximationPhrase: Bool, ifZero: String) -> String {
        if seconds == 0 {
            return ifZero
        } else if seconds < 0 {
            // Should never happen but an OctoPrint plugin is returning negative values
            // so return 'Unknown' when this happens
            return NSLocalizedString("Unknown", comment: "ETA is Unknown")
        }
        let duration = TimeInterval(seconds)
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .brief
        formatter.includesApproximationPhrase = includesApproximationPhrase
        formatter.allowedUnits = [ .day, .hour, .minute ]
        return formatter.string(from: duration)!
    }
    /// Converts number of seconds into a string that represents time (e.g. 23h 10m)
    static func secondsToPrintTime(seconds: Int) -> String {
        let duration = TimeInterval(seconds)
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .brief
        formatter.allowedUnits = [ .day, .hour, .minute, .second ]
        formatter.zeroFormattingBehavior = [ .default ]
        return formatter.string(from: duration)!
    }
    /// Return estimated complection date based on number of estimated seconds to completion
    /// - parameter seconds: estimated number of seconds to complection
    static func secondsToETA(seconds: Int) -> String {
        if seconds == 0 {
            return ""
        } else if seconds < 0 {
            // Should never happen but an OctoPrint plugin is returning negative values
            // so return 'Unknown' when this happens
            return NSLocalizedString("Unknown", comment: "ETA is Unknown")
        }
        
        let calendar = Calendar.current
        let now = Date()
        if let etaDate = calendar.date(byAdding: .second, value: seconds, to: now) {
            let formatter = DateFormatter()
            if Calendar.current.isDate(now, inSameDayAs:etaDate) {
                // Same day so just show hour
                formatter.dateStyle = .none
                formatter.timeStyle = .short
            } else {
                // Show short version of date and hour
                formatter.dateStyle = .short
                formatter.timeStyle = .short
            }
            return formatter.string(from: etaDate)
        } else {
            NSLog("Failed to create ETA date")
            return ""
        }
    }
    static func isValidURL(urlString: String) -> Bool {

             let urlRegEx = "(http|https)://((\\w)*|([0-9]*)|([-|_]|[\\.|/])*)+(:[0-9]+)?"
             let urlTest = NSPredicate(format: "SELF MATCHES %@", urlRegEx)
             var result = urlTest.evaluate(with: urlString)
             if !result {
                 let ipv6RegEx = "(http|https)://(\\[)?(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))(])?(:[0-9]+)?"
                 let ipv6Test = NSPredicate(format: "SELF MATCHES %@", ipv6RegEx)
                 result = ipv6Test.evaluate(with: urlString)
             }
             return result
     }
}

#if canImport(UIKit)
// iOS, tvOS, and watchOS – use UIKit
extension UIImage {
    func resizeWithWidth(width: CGFloat) -> UIImage? {
        let imageView = UIImageView(frame: CGRect(origin: .zero, size: CGSize(width: width, height: CGFloat(ceil(width/size.width * size.height)))))
        imageView.contentMode = .scaleAspectFit
        imageView.image = self
        UIGraphicsBeginImageContextWithOptions(imageView.bounds.size, false, scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        imageView.layer.render(in: context)
        guard let result = UIGraphicsGetImageFromCurrentImageContext() else { return nil }
        UIGraphicsEndImageContext()
        return result
    }
}
#else
// all other platforms meaning macOS
#endif

extension Date {
    func timeAgoDisplay() -> String {
        let secondsAgo = Int(Date().timeIntervalSince(self))
        let minute = 60
        let hour = 60 * minute
        let day = 24 * hour
        let week = 7 * day
        if secondsAgo < minute {
            return String(format: NSLocalizedString("seconds ago", comment: ""), secondsAgo)
        }
            
        else if secondsAgo < hour {
            let minutes = secondsAgo / minute
            return minutes == 1 ? NSLocalizedString("1 minute ago", comment: "") : String(format: NSLocalizedString("minutes ago", comment: ""), minutes)
        }
        else if secondsAgo < day {
            let hours = secondsAgo / hour
            return hours == 1 ? NSLocalizedString("1 hour ago", comment: "") : String(format: NSLocalizedString("hours ago", comment: ""), hours)
        }
        else if secondsAgo < week {
            let days = secondsAgo / day
            return days == 1 ? NSLocalizedString("1 day ago", comment: "") : String(format: NSLocalizedString("days ago", comment: ""), days)
        }
        let weeks = secondsAgo / week
        return weeks == 1 ? NSLocalizedString("1 week ago", comment: "") :  String(format: NSLocalizedString("weeks ago", comment: ""), weeks)
    }
}
