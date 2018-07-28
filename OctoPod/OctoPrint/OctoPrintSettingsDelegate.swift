import Foundation
import UIKit

protocol OctoPrintSettingsDelegate: class {
    
    // Notificatoin that camera orientation has changed
    func cameraOrientationChanged(newOrientation: UIImageOrientation)

    // Notificatoin that sd support has changed
    func sdSupportChanged(sdSupport: Bool)
}
