import WatchKit
import Foundation


class PrintersInterfaceController: WKInterfaceController, PrinterManagerDelegate {
    
    @IBOutlet weak var syncPrintersLabel: WKInterfaceLabel!
    @IBOutlet weak var printersTable: WKInterfaceTable!
    @IBOutlet weak var refreshButton: WKInterfaceButton!
    
    var printers: [[String: Any]]!

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Configure interface objects here.
        syncPrintersLabel.setHidden(true)
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()

        // Listen to changes to list of printers
        PrinterManager.instance.delegates.append(self)
        
        // Update table based on list of printers we have
        updateTable()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()

        // Stop listening to changes to list of printers
        PrinterManager.instance.remove(printerManagerDelegate: self)
    }
    
    override func table(_ table: WKInterfaceTable, didSelectRowAt rowIndex: Int) {
        // Update selected printer
        let printerName = PrinterManager.instance.name(printer: printers[rowIndex])
        PrinterManager.instance.changeDefaultPrinter(printerName: printerName)
        // Refresh table
        updateTable()
        // Update OctoPrintClient to point to newly selected printer
        OctoPrintClient.instance.configure()
    }

    @IBAction func refresh() {
        // Disable refresh button to indicate we are "refreshing"
        self.refreshButton.setEnabled(false)
        WatchSessionManager.instance.refreshPrinters {
            DispatchQueue.main.async {
                // Done refreshing so enable button again
                self.refreshButton.setEnabled(true)
            }
        }
    }
    
    // MARK: - PrinterManagerDelegate
    
    // Notification that list of printers has changed. Could be that new
    // ones were added, or updated or deleted. Change was pushed from iOS app
    // to the Apple Watch
    func printersChanged() {
        // Refresh table
        updateTable()
    }
    
    // Notification that selected printer has changed due to a remote change
    // Remote change could be from iPhone or iPad. Local changes do not trigger
    // this notification
    func defaultPrinterChanged(newDefault: [String: Any]?) {
        // Do nothing
    }
    
    // Notification that an image has been received from a received file
    // If image is nil then that means that there was an error reading
    // the file to get the image
    func imageReceived(image: UIImage?, cameraId: String) {
        // Do nothing
    }
    
    // MARK: - Private functions
    
    fileprivate func updateTable() {
        printers = PrinterManager.instance.printers
        
        syncPrintersLabel.setHidden(!printers.isEmpty)
        refreshButton.setHidden(printers.isEmpty)
        
        // Set number of rows based on printers count
        printersTable.setNumberOfRows(printers.count, withRowType: "PrinterTableRowController")
        
        for (index, printer) in printers.enumerated() {
            let row = printersTable.rowController(at: index) as! PrinterTableRowController
            
            let printerName = PrinterManager.instance.name(printer: printer)
            row.printerLabel.setText(printerName)
            row.checkmarkImage.setHidden(!PrinterManager.instance.isDefault(printer: printer))
        }
    }
}
