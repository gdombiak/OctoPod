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

}

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
