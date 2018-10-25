import WatchKit
import Foundation


class PrintersInterfaceController: WKInterfaceController, PrinterManagerDelegate {
    
    @IBOutlet weak var printersTable: WKInterfaceTable!
    
    var printers: [[String: Any]]!

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Configure interface objects here.
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
    
    // MARK: - Private functions
    
    fileprivate func updateTable() {
        printers = PrinterManager.instance.printers
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
