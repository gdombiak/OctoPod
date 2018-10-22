import Foundation

class PrinterManager {
    
    static let instance = PrinterManager()
    
    var delegates: Array<PrinterManagerDelegate> = []
    
    private(set) var printers: [[String: Any]] = []
    
    // Update list of printers stored in memory
    // Information came from iOS App and we need to update
    // what we have in memory.
    // Listeners will be notified of changes
    func updatePrinters(printers: [[String: Any]]) {
        NSLog("Received new printers: \(printers)")
        
        let previousDefaultPrinter = defaultPrinter()
        
        self.printers = printers

        let currentDefaultPrinter = defaultPrinter()

        if !samePrinter(printerL: previousDefaultPrinter, printerR: currentDefaultPrinter) {
            // Notify that default printer has changed
            for delegate in delegates {
                delegate.defaultPrinterChanged(newDefault: currentDefaultPrinter)
            }
        }
        // Notify listeners that printers have changed
        for delegate in delegates {
            delegate.printersChanged()
        }
    }
    
    // Apple Watch selected new default printer. Update locally and request
    // iOS App to reflect new change
    func changeDefaultPrinter(printerName: String) {
        // Update local printers to have new default printer
        for (index, printer) in printers.enumerated() {
            printers[index]["isDefault"] = name(printer: printer) == printerName
        }
        // Request iOS App to update selected printer
        WatchSessionManager.instance.updateApplicationContext(context: ["selected_printer" : printerName])
    }
    
    // Returns default printer. This is the selected printer by the user
    func defaultPrinter() -> [String: Any]? {
        for printer in printers {
            if isDefault(printer: printer) {
                return printer
            }
        }
        return nil
    }
    
    // MARK: - Delegates operations
    
    func remove(printerManagerDelegate toRemove: PrinterManagerDelegate) {
        delegates.removeAll(where: { $0 === toRemove })
    }

    // MARK: - Printer Properties - parsed
    
    func name(printer: [String: Any]) -> String {
        return printer["name"] as! String
    }

    func hostname(printer: [String: Any]) -> String {
        return printer["hostname"] as! String
    }

    func apiKey(printer: [String: Any]) -> String {
        return printer["apiKey"] as! String
    }

    func isDefault(printer: [String: Any]) -> Bool {
        return printer["isDefault"] as! Bool
    }
    
    func username(printer: [String: Any]) -> String? {
        return printer["username"] as? String
    }

    func password(printer: [String: Any]) -> String? {
        return printer["password"] as? String
    }

    func cameras(printer: [String: Any]) -> [(url: String, orientation: Int)]? {
        if let cameras = printer["cameras"] as? Array<Dictionary<String, Any>> {
            var result: [(url: String, orientation: Int)] = Array()
            for camera in cameras {
                result.append((url: camera["url"] as! String, orientation: camera["orientation"] as! Int))
            }
            return result
        }
        return nil
    }
    
    // MARK: - Private functions
    
    // Compare of two printers are equal
    fileprivate func samePrinter(printerL: [String: Any]?, printerR: [String: Any]?) -> Bool {
        if printerL == nil && printerR == nil {
            return true
        }
        
        if printerL != nil && printerR == nil {
            return false
        }

        if printerL == nil && printerR != nil {
            return false
        }
        
        return name(printer: printerL!) == name(printer: printerR!) && hostname(printer: printerL!) == hostname(printer: printerR!) && apiKey(printer: printerL!) == apiKey(printer: printerR!) && isDefault(printer: printerL!) == isDefault(printer: printerR!)
    }
}
