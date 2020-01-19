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
    
    func updateComplications(info: [String : Any]) {
        if let printerName = info["printer"] as? String, let state = info["state"] as? String, let completion = info["completion"] as? Double {
            for delegate in delegates {
                delegate.updateComplications(printerName: printerName, printerState: state, completion: completion)
            }
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
