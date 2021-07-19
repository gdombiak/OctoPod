import Foundation

/// Manager for changing default printer and notifying listeners
/// when new printer has been selected
class DefaultPrinterManager {
    private let printerManager: PrinterManager!
    private let octoprintClient: OctoPrintClient!
    private let watchSessionManager: WatchSessionManager!

    var delegates: Array<DefaultPrinterManagerDelegate> = []

    init(printerManager: PrinterManager, octoprintClient: OctoPrintClient, watchSessionManager: WatchSessionManager) {
        self.printerManager = printerManager
        self.octoprintClient = octoprintClient
        self.watchSessionManager = watchSessionManager
        // We have a circular reference so break it by doing this ugly trick
        watchSessionManager.defaultPrinterManager = self
    }
    
    func changeToDefaultPrinter(printer: Printer, updateWatch: Bool = true, connect: Bool = true) {
        // Update stored printers
        printerManager?.changeToDefaultPrinter(printer)
        if updateWatch {
            // Update Apple Watch with new selected printer
            watchSessionManager.pushPrinters()
        }
        if connect {
            // Ask octoprintClient to connect to new OctoPrint server
            octoprintClient.connectToServer(printer: printer)
        }
        // Notify listeners of this change (ugly hack: use watch session listeners. Should be refactored)
        for delegate in delegates {
            delegate.defaultPrinterChanged()
        }
    }

    // MARK: - Navbar Swipe operations
    
    enum SwipeDirection {
        case left
        case right
    }
    
    func navigationBarSwiped(direction: SwipeDirection) {
        if let printer = printerManager.getDefaultPrinter() {
            // Swipe to change between printers
            let printers = printerManager.getPrinters()
            if printers.count < 2 {
                // Nothing to do since there is only one OctoPrint instance (aka printer)
                return
            }
            
            var newPrinter: Printer!
            if let index = printers.firstIndex(of: printer) {
                if direction == .left {
                    // Right to left so move to the next printer
                    if index == printers.count - 1 {
                        // Go to the first printer in the array
                        newPrinter = printers[0]
                    } else {
                        // Go to the next printer in the array
                        newPrinter = printers[index + 1]
                    }
                } else {
                    // Left to right so move to the previous printer
                    if index == 0 {
                        // Go to the last printer in the array
                        newPrinter = printers.last
                    } else {
                        // Go to the previous printer in the array
                        newPrinter = printers[index - 1]
                    }
                }

                // Change default printer
                changeToDefaultPrinter(printer: newPrinter)
            }
        }
    }

    // MARK: - Delegates operations
    
    func remove(defaultPrinterManagerDelegate toRemove: DefaultPrinterManagerDelegate) {
        delegates.removeAll(where: { $0 === toRemove })
    }
}
