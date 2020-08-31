import Foundation
import Starscream
#if canImport(UIKit)
// iOS, tvOS, and watchOS – use UIKit
import UIKit
#else
// all other platforms meaning macOS
#endif

/// Listener that reacts to changes in OctoPrint Settings (/api/settings)
/// This is done via the OctoPrint admin console
protocol OctoPrintSettingsDelegate: class {
    
    /// Notification that orientation of the camera hosted by OctoPrint has changed
    
    #if canImport(UIKit)
    // iOS, tvOS, and watchOS – use UIKit
    func cameraOrientationChanged(newOrientation: UIImage.Orientation)
    #else
    // all other platforms meaning macOS
    #endif

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
    /// - parameter installed: True if plugin is installed in OctoPrint
    func cancelObjectAvailabilityChanged(installed: Bool)
    
    /// Notification that OctoPrint's appearance has changed. A new color or its transparency has changed
    func octoPrintColorChanged(color: String)

    /// Notification that availability of OctoPod plugin has changed
    /// - parameter installed: True if plugin is installed in OctoPrint
    func octoPodPluginChanged(installed: Bool)

    /// Notification that availability of Palette2 plugin has changed or its settings changed
    /// - parameter installed: True if plugin is installed in OctoPrint
    func palette2Changed(installed: Bool)

    /// Notification that availability of Palette2 Canvas plugin has changed
    /// - parameter installed: True if plugin is installed in OctoPrint
    func palette2CanvasAvailabilityChanged(installed: Bool)
    
    /// Notification that inputs of Enclosure plugin have changed
    func enclosureInputsChanged()

    /// Notification that outputs of Enclosure plugin have changed
    func enclosureOutputsChanged()
    
    /// Notification that availability of FilamentManager plugin has changed
    /// - parameter installed: True if plugin is installed in OctoPrint
    func filamentManagerAvailabilityChanged(installed: Bool)
}


// Make everything optional so implementors of this protocol are not forced to implement everything
extension OctoPrintSettingsDelegate {
    #if canImport(UIKit)
    // iOS, tvOS, and watchOS – use UIKit
    func cameraOrientationChanged(newOrientation: UIImage.Orientation) {
    }
    #else
    // all other platforms meaning macOS
    #endif
    
    
    
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
    
    func palette2Changed(installed: Bool) {
    }
    
    func palette2CanvasAvailabilityChanged(installed: Bool) {        
    }
    
    func enclosureInputsChanged() {
    }

    func enclosureOutputsChanged() {
    }
    
    func filamentManagerAvailabilityChanged(installed: Bool) {
    }
}
