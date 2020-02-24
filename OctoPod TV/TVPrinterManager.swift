import Foundation

class TVPrinterManager: ObservableObject, CloudKitPrinterDelegate {
    @Published var printers: [Printer]
    @Published var defaultPrinter: Printer?
    @Published var iCloudConnected = true

    let printerManager: PrinterManager
    let cloudKitPrinterManager: CloudKitPrinterManager

    init(printerManager: PrinterManager, cloudKitPrinterManager: CloudKitPrinterManager) {
        self.printerManager = printerManager
        self.cloudKitPrinterManager = cloudKitPrinterManager
        
        self.printers = self.printerManager.getPrinters()
        self.defaultPrinter = self.printerManager.getDefaultPrinter()

        cloudKitPrinterManager.delegates.append(self)
    }
    
    // MARK: - CloudKitPrinterDelegate
    
    func printersUpdated() {
        refreshState()
    }

    func printerAdded(printer: Printer) {
        refreshState()
    }
    
    func printerUpdated(printer: Printer) {
        refreshState()
    }
    
    func printerDeleted(printer: Printer) {
        refreshState()
    }
    
    func iCloudStatusChanged(connected: Bool) {
        DispatchQueue.main.async {
            self.iCloudConnected = connected
        }
    }
    
    // MARK: - Private functions

    fileprivate func refreshState() {
        DispatchQueue.main.async {
            self.printers = self.printerManager.getPrinters()
            self.defaultPrinter = self.printerManager.getDefaultPrinter()
        }
        
        // Wait few seconds before looking for duplicates
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
            self.checkForDuplicates()
        }
    }
    
    /// It seems like iCloud maybe be merging a backup of Core Data for AppleTV after we
    /// synched records from iCloud so we will end up with duplicated printers. Check if
    /// this happened and reset local printers
    fileprivate func checkForDuplicates() {
        var duplicatesFound = false
        var names = Array<String>()
        let existingPrinters = printerManager.getPrinters()
        for printer in existingPrinters {
            if names.contains(printer.name) {
                duplicatesFound = true
                break
            } else {
                names.append(printer.name)
            }
        }
        if duplicatesFound {
            let oldCopy = self.printers
            NSLog("Deleting duplicates printer entries")
            self.cloudKitPrinterManager.resetLocalPrinters(completionHandler: {
                NSLog("Core Data duplicates removed. Before \(oldCopy.count) Now \(self.printers.count)")
                NSLog("Before \(existingPrinters.count) Now \(self.printerManager.getPrinters().count)")
            }) {
                NSLog("Error removing Core Data duplicates")
            }
        }
    }
}
