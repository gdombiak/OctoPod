import Foundation
import UIKit

/// Listener that reacts to changes in OctoPrint Settings (/api/settings)
/// This is done via the OctoPrint admin console
protocol OctoPrintSettingsDelegate: class {
    
    /// Notification that orientation of the camera hosted by OctoPrint has changed
    func cameraOrientationChanged(newOrientation: UIImage.Orientation)

    /// Notification that path to camera hosted by OctoPrint has changed
    func cameraPathChanged(streamUrl: String)
    
    /// Notification that a new camera has been added or removed. We rely on MultiCam
    /// plugin to be installed on OctoPrint so there is no need to re-enter this information
    /// URL to cameras is returned in /api/settings under plugins->multicam
    func camerasChanged(camerasURLs: Array<String>)
    
    /// Notification that availability of PSU Control plugin has changed
    func psuControlAvailabilityChanged(installed: Bool)

    /// Notification that an IP plug plugin has changed. Could be availability or settings
    func ipPlugsChanged(plugin: String, plugs: Array<IPPlug>)

    /// Notification that sd support has changed
    func sdSupportChanged(sdSupport: Bool)
    
    /// Notification that availability of Cancel Object plugin has changed
    func cancelObjectAvailabilityChanged(installed: Bool)
    
    /// Notification that OctoPrint's appearance has changed. A new color or its transparency has changed
    func octoPrintColorChanged(color: String)

    /// Notification that availability of OctoPod plugin has changed
    func octoPodPluginChanged(installed: Bool)
}


// Make everything optional so implementors of this protocol are not forced to implement everything
extension OctoPrintSettingsDelegate {
    
    func cameraOrientationChanged(newOrientation: UIImage.Orientation) {
    }
    
    func cameraPathChanged(streamUrl: String) {        
    }
    
    func camerasChanged(camerasURLs: Array<String>) {
    }

    func psuControlAvailabilityChanged(installed: Bool) {
    }

    func ipPlugsChanged(plugin: String, plugs: Array<IPPlug>) {
    }

    func sdSupportChanged(sdSupport: Bool) {
    }
    
    func cancelObjectAvailabilityChanged(installed: Bool) {        
    }

    func octoPrintColorChanged(color: String) {
    }

    func octoPodPluginChanged(installed: Bool){
    }
}
