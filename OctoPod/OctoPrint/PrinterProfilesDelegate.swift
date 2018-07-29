import Foundation

// Listener that reacts to changes in Print Profile (/api/printerprofiles)
// This is done via the OctoPrint admin console
protocol PrinterProfilesDelegate: class {

    // Notification that axis direction has changed
    func axisDirectionChanged(axis: OctoPrintClient.axis, inverted: Bool)

}
