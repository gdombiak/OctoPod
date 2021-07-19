import Foundation

class TVPrinterManager: ObservableObject, CloudKitPrinterDelegate {
    @Published var printers: [Printer] = []
    @Published var iCloudConnected = true

    let printerManager: PrinterManager
    let cloudKitPrinterManager: CloudKitPrinterManager
    
    private(set) var connections: [Printer: (websocket: ViewService, cameraService: CameraService)] = [:]
    /// Remember which connections should be active. Active printers are those that appear in main view.
    /// When app becomes active these connections will be reestablished. Printer name is stored in Array
    private var active: Array<String> = Array()

    init(printerManager: PrinterManager, cloudKitPrinterManager: CloudKitPrinterManager) {
        self.printerManager = printerManager
        self.cloudKitPrinterManager = cloudKitPrinterManager

        self.updatePrinters(newPrinters: self.printerManager.getPrinters())

        cloudKitPrinterManager.delegates.append(self)
    }
    
    // MARK: - Connection handling
    
    /// Open websocket connection and refresh camera connection/thread for selected printer; and
    /// keep printer in the list of active connections. This is useful for temporary halts (see #suspendConnections)
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

    /// Close websocket connection and refresh camera connection/thread for selected printer; and
    /// remove printer from list of active connections.
    func disconnectFromServer(printerIndex: Int) {
        if printers.count - 1 >= printerIndex {
            self.disconnectFromServer(printer: printers[printerIndex])
        }
    }
    
    /// Close websocket connection and refresh camera connection/thread for active printers but
    /// still remember active printers. This is useful when tvOS app is no longer active. User may be
    /// in whatever page (pagination in Main view) so we need to remember which printers were active
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

    /// Open websocket connection and refresh camera connection/thread for active printers for active
    /// printers. This is useful when tvOS app becomes active again. Active printers are those that user see in
    /// main view
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
    
    /// Close refresh camera connection/thread for all active printers except for specified one. List
    /// of active printers is not modified. Camera connections is what consumes most of the CPU
    /// so closing them when not being displayed is a good thing to save on.
    func suspendOtherCameraConnections(skip: String) {
        for printerName in active {
            if printerName == skip {
                continue
            }
            if let printer = printers.first(where: {$0.name == printerName}) {
                // Stop rendering camera of printer
                self.connections[printer]?.cameraService.disconnectFromServer()
            }
        }
    }

    /// Open refresh camera connection/thread for all active printers except for specified one. List
    /// of active printers is not modified. Camera connections is what consumes most of the CPU
    /// so closing them when not being displayed is a good thing to save on.
    func resumeOtherCameraConnections(skip: String) {
        for printerName in active {
            if printerName == skip {
                continue
            }
            if let printer = printers.first(where: {$0.name == printerName}) {
                // Start rendering camera of printer
                self.connections[printer]?.cameraService.connectToServer(printer: printer)
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
    
    // MARK: - Notifications
    
    func cameraChanged(printerName: String) {
        DispatchQueue.main.async {
            // Fetch updated printer
            if let updatedPrinter = self.printerManager.getPrinterByName(name: printerName) {
                // Look for old printer
                var exist: Printer?
                for printer in self.printers {
                    if self.samePrinter(printer, updatedPrinter) {
                        // Found same printer
                        exist = printer
                        break
                    }
                }
                if let oldPrinter = exist {
                    // Retrieve existing cameraService that is rendering old camera info
                    if let cameraService = self.connections[oldPrinter]?.cameraService {
                        // Stop rendering old data
                        cameraService.disconnectFromServer()
                        // Update camera service to use newest camera info and render new camera
                        cameraService.connectToServer(printer: updatedPrinter)
                    }
                }
            }
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
                newConnections[newPrinter] = (ViewService(tvPrinterManager: self), CameraService())
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
