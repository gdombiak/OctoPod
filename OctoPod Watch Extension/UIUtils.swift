import Foundation
import WatchKit

class UIUtils {
    
    // Caller may not be running in Main thread
    static func showAlert(presenter: WKInterfaceController, title: String, message: String, done: (() -> Void)?) {
        // We are not always on the main thread so present dialog on main thread to prevent crashes
        DispatchQueue.main.async {
            let dismissText = NSLocalizedString("Dismiss", comment: "")
            let action1 = WKAlertAction(title: dismissText, style: WKAlertActionStyle.default, handler: {
                // Execute done block on dismiss
                done?()
            })
            
            presenter.presentAlert(withTitle: title, message: message, preferredStyle: .alert, actions: [action1])
        }
    }

    // Caller MUST be running in Main thread
    static func showConfirm(presenter: WKInterfaceController, message: String, yes: @escaping () -> Void, no: (() -> Void)?) {
        let yesText = NSLocalizedString("Yes", comment: "")
        let action1 = WKAlertAction(title: yesText, style: WKAlertActionStyle.default, handler: {
            yes()
        })
        let noText = NSLocalizedString("No", comment: "")
        let action2 = WKAlertAction(title: noText, style: WKAlertActionStyle.cancel, handler: {
            no?()
        })
        
        let confirmTitle = NSLocalizedString("Confirm", comment: "")
        presenter.presentAlert(withTitle: confirmTitle, message: message, preferredStyle: .alert, actions: [action1, action2])

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
}
