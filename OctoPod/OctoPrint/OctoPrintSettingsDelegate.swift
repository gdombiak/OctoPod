import Foundation
import UIKit

// Listener that reacts to changes in OctoPrint Settings (/api/settings)
// This is done via the OctoPrint admin console
protocol OctoPrintSettingsDelegate: class {
    
    // Notification that orientation of the camera hosted by OctoPrint has changed
    func cameraOrientationChanged(newOrientation: UIImageOrientation)

    // Notification that a new camera has been added or removed. We rely on MultiCam
    // plugin to be installed on OctoPrint so there is no need to re-enter this information
    // URL to cameras is returned in /api/settings under plugins->multicam
    func camerasChanged(camerasURLs: Array<String>)

    // Notification that sd support has changed
    func sdSupportChanged(sdSupport: Bool)
}
