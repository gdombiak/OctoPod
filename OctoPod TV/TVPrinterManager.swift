import Foundation

class TVPrinterManager: ObservableObject, CloudKitPrinterDelegate {
    @Published var printers: [Printer] = []
    @Published var iCloudConnected = true

    let printerManager: PrinterManager
    let cloudKitPrinterManager: CloudKitPrinterManager
    
    private(set) var connections: [Printer: (websocket: ViewService, cameraService: CameraService)] = [:]

    init(printerManager: PrinterManager, cloudKitPrinterManager: CloudKitPrinterManager) {
        self.printerManager = printerManager
        self.cloudKitPrinterManager = cloudKitPrinterManager

        self.updatePrinters(newPrinters: self.printerManager.getPrinters())

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

    fileprivate func updatePrinters(newPrinters: [Printer]) {
        // Setup new connections before Views use them
        for printer in newPrinters {
            self.connections[printer] = (ViewService(), CameraService())
        }
        self.printers = newPrinters
        
        // Open websocket and start rendering cameras
        for printer in self.printers {
            // Open websocket to printer
            self.connections[printer]?.websocket.connectToServer(printer: printer)
            // Start rendering camera of printer
            self.connections[printer]?.cameraService.connectToServer(printer: printer)
        }
    }
    
    fileprivate func refreshState() {
        // TODO: - Check if new printers are different from existing ones
        // TODO: - Disconnect existing websocket and camera service

        DispatchQueue.main.async {
            self.updatePrinters(newPrinters: self.printerManager.getPrinters())
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
