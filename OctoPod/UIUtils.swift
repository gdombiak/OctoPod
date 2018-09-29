import Foundation
import UIKit

class UIUtils {

    // Caller may not be running in Main thread
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
    
    // Caller MUST be running in Main thread
    static func showConfirm(presenter: UIViewController, message: String, yes: @escaping (UIAlertAction) -> Void, no: @escaping (UIAlertAction) -> Void) {
        let alert = UIAlertController(title: NSLocalizedString("Confirm", comment: ""), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Yes", comment: ""), style: .default, handler: yes))
        // Use default style and not cancel style for NO so it appears on the right
        alert.addAction(UIAlertAction(title: NSLocalizedString("No", comment: ""), style: .default, handler: no))
        presenter.present(alert, animated: true) { () -> Void in
            // Nothing to do here
        }
    }
}
