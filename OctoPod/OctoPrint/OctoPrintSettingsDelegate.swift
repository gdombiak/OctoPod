import Foundation
import UIKit

// Listener that reacts to changes in OctoPrint Settings (/api/settings)
// This is done via the OctoPrint admin console
protocol OctoPrintSettingsDelegate: class {
    
    // Notification that camera orientation has changed
    func cameraOrientationChanged(newOrientation: UIImageOrientation)

    // Notification that sd support has changed
    func sdSupportChanged(sdSupport: Bool)
}
