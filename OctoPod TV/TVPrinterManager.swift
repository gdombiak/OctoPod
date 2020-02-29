import Foundation

class TVPrinterManager: ObservableObject, CloudKitPrinterDelegate {
    @Published var printers: [Printer] = []
    @Published var iCloudConnected = true

    let printerManager: PrinterManager
    let cloudKitPrinterManager: CloudKitPrinterManager
    
    private(set) var connections: [Printer: (websocket: ViewService, cameraService: CameraService)] = [:]
    /// Remember which connections should be active. When becomes active these connections will be reestablished
    private var active: Array<String> = Array()

    init(printerManager: PrinterManager, cloudKitPrinterManager: CloudKitPrinterManager) {
        self.printerManager = printerManager
        self.cloudKitPrinterManager = cloudKitPrinterManager

        self.updatePrinters(newPrinters: self.printerManager.getPrinters())

        cloudKitPrinterManager.delegates.append(self)
    }
    
    // MARK: - Connection handling
    
    func connectToServer(printerIndex: Int) {
        if printers.count - 1 >= printerIndex {
            let printer = printers[printerIndex]
            // Open websocket to printer
            self.connections[printer]?.websocket.connectToServer(printer: printer)
            // Start rendering camera of printer
            self.connections[printer]?.cameraService.connectToServer(printer: printer)
            // Track that connection to this printer is active
            active.append(printer.name)
        }
    }

    func disconnectFromServer(printerIndex: Int) {
        if printers.count - 1 >= printerIndex {
            self.disconnectFromServer(printer: printers[printerIndex])
        }
    }
    
    func resumeConnections() {
        for printerName in active {
            if let printer = printers.first(where: {$0.name == printerName}) {
                // Open websocket to printer
                self.connections[printer]?.websocket.connectToServer(printer: printer)
                // Start rendering camera of printer
                self.connections[printer]?.cameraService.connectToServer(printer: printer)
            }
        }
    }

    func suspendConnections() {
        for printerName in active {
            if let printer = printers.first(where: {$0.name == printerName}) {
                // Close websocket to printer
                self.connections[printer]?.websocket.disconnectFromServer()
                // Stop rendering camera of printer
                self.connections[printer]?.cameraService.disconnectFromServer()
            }
        }
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

    fileprivate func samePrinter(_ printer: Printer, _ newPrinter: Printer) -> Bool {
        return printer.name == newPrinter.name && printer.hostname == newPrinter.hostname && printer.recordName == newPrinter.recordName
    }
    
    fileprivate func updatePrinters(newPrinters: [Printer]) {
        var newConnections: [Printer: (websocket: ViewService, cameraService: CameraService)] = [:]
        var sortedPrinters = newPrinters
        
        // Create or reuse existing websocket and camera connections
        for newPrinter in newPrinters {
            var exist: Printer?
            for printer in printers {
                if samePrinter(printer, newPrinter) {
                    // Found same printer
                    exist = printer
                    break
                }
            }
            if let existingPrinter = exist {
                // Reuse existing connections
                newConnections[newPrinter] = self.connections[existingPrinter]
            } else {
                // Setup new connections for new printer
                newConnections[newPrinter] = (ViewService(), CameraService())
            }
        }
        // Close no longer needed connections
        for printer in printers {
            if !newPrinters.contains(where: { samePrinter($0, printer) }) {
                disconnectFromServer(printer: printer)
            }
        }

        // Store new valid conections for new printers
        self.connections = newConnections
        
        // Sort printers by name (in the future could be by status so printing appear first)
        sortedPrinters.sort { (left, right) -> Bool in
            return left.name < right.name
        }
        
        // Store sorted new printers
        self.printers = sortedPrinters
    }
    
    fileprivate func refreshState() {
        DispatchQueue.main.async {
            self.updatePrinters(newPrinters: self.printerManager.getPrinters())
        }
    }
    
    fileprivate func disconnectFromServer(printer: Printer) {
        // Close websocket to printer
        self.connections[printer]?.websocket.disconnectFromServer()
        // Stop rendering camera of printer
        self.connections[printer]?.cameraService.disconnectFromServer()
        // Track that connection to this printer is no longer active
        active.removeAll(where: { $0 == printer.name})
    }

}
