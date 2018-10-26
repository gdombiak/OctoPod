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

}
