import Foundation

/// Listener that reacts to changes in Print Profile (/api/printerprofiles)
/// This is done via the OctoPrint admin console
protocol PrinterProfilesDelegate: AnyObject {

    /// Notification that axis direction has changed
    func axisDirectionChanged(axis: axis, inverted: Bool)
    
    /// Notification that information about extruders and nozzle has changed
    func toolsChanged(toolsNumber: Int16, sharedNozzle: Bool)

}
