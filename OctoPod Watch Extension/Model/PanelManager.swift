import Foundation
import UIKit

class PanelManager: PrinterManagerDelegate {
    
    static let instance = PanelManager()

    var delegates: Array<PanelManagerDelegate> = Array()
    
    private(set) var printerName: String? // Name of the printer whose information we last refreshed
    private(set) var panelInfo: [String : Any]? // Keep track of current (last known) panel information
    private(set) var lastRefresh: Date? // Date when panel information was last fetched

    init() {
        // Listen to changes to selected or list of printers
        PrinterManager.instance.delegates.append(self)
    }

    // MARK: - Refresh operations

    /// Fetch current job information and then update complications and main panel window. Job information will be first attempted
    /// to be loaded via iOS app and direct HTTP request as a fallback mechanism. When going via iOS app more information is included
    /// like printer state and Palette 2 ping statistics. This method is called when 1. a new printer has been selected, 2. main Panel window
    /// refreshes data, 3. printers data has changed (like name)
    func refresh(done: (() -> Void)?) {
        if let printer = PrinterManager.instance.defaultPrinter() {
            printerName = PrinterManager.instance.name(printer: printer)
            let currentPrinterName = printerName
            // There is a default printer so fetch panel information
            OctoPrintClient.instance.currentJobInfo { (reply: [String : Any]) in
                // Check that current printer is still the same one we had before we made the request
                if let currentPrinter = PrinterManager.instance.defaultPrinter() {
                    if currentPrinterName == PrinterManager.instance.name(printer: currentPrinter) {
                        self.panelInfo = reply
                        self.lastRefresh = Date()
                        
                        // Notify listeners that we have new panel information
                        for delegate in self.delegates {
                            delegate.panelInfoUpdate(printerName: self.printerName!, panelInfo: reply)
                        }
                    }
                    done?()
                }
            }
        } else {
            printerName = nil
            panelInfo = nil
            lastRefresh = nil
        }
    }
    
    /// Update complications with new updated data. This is requested when iOS app deteced that printer changed state. ComplicationController
    /// also has a background refresh task that updates complications information. Complications are also updated from Apple Watch when it detects
    /// 1. a new printer has been selected, 2. main Panel window refreshed data, 3. printers data has changed (like name). See refresh(:) above
    func updateComplications(info: [String : Any]) {
        if let printerName = info["printer"] as? String, let state = info["state"] as? String, let completion = info["completion"] as? Double {
            // Retrieve Palette 2 information if available
            let palette2LastPing: String? = info["palette2LastPing"] as? String
            let palette2LastVariation: String? = info["palette2LastVariation"] as? String
            let palette2MaxVariation: String? = info["palette2MaxVariation"] as? String
            for delegate in delegates {
                delegate.updateComplications(printerName: printerName, printerState: state, completion: completion, palette2LastPing: palette2LastPing, palette2LastVariation: palette2LastVariation, palette2MaxVariation: palette2MaxVariation)
            }
        }
    }

    func updateComplicationsContentType(contentType: String) {
        for delegate in delegates {
            delegate.updateComplicationsContentType(contentType: contentType)
        }
    }
    
    // MARK: - Delegates operations
    
    func remove(panelManagerDelegate toRemove: PanelManagerDelegate) {
        delegates = delegates.filter({ (delegate) -> Bool in
            return delegate !== toRemove
        })
    }
    
    // MARK: - PrinterManagerDelegate
    
    // Notification that list of printers has changed. Could be that new
    // ones were added, or updated or deleted. Change was pushed from iOS app
    // to the Apple Watch
    func printersChanged() {
        // Clear known last state
        printerName = nil
        panelInfo = nil
        lastRefresh = nil

        // Fetch state
        refresh(done: nil)
    }
    
    // Notification that selected printer has changed due to a remote change
    // Remote change could be from iPhone or iPad. Local changes do not trigger
    // this notification
    func defaultPrinterChanged(newDefault: [String: Any]?) {
        // Clear known last state
        printerName = nil
        panelInfo = nil
        lastRefresh = nil

        // Fetch state
        refresh(done: nil)
    }
    
    // Notification that an image has been received from a received file
    // If image is nil then that means that there was an error reading
    // the file to get the image
    func imageReceived(image: UIImage?, cameraId: String) {
        // Do nothing
    }
}
