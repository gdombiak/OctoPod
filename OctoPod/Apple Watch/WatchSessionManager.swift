import Foundation
import WatchConnectivity

class WatchSessionManager: NSObject, WCSessionDelegate, CloudKitPrinterDelegate {

    var printerManager: PrinterManager
    var octoprintClient: OctoPrintClient
    var session: WCSession?
    
    var delegates: Array<WatchSessionManagerDelegate> = []

    init(printerManager: PrinterManager, cloudKitPrinterManager: CloudKitPrinterManager, octoprintClient: OctoPrintClient) {
        self.printerManager = printerManager
        self.octoprintClient = octoprintClient
        super.init()
        
        // Listen to iCloud changes. Printers may be modified from iPad and
        // when iPhone gets notified then we will reach and push to Apple Watch
        cloudKitPrinterManager.delegates.append(self)
    }

    func start() {
        if (WCSession.isSupported()) {
            session = WCSession.default
            
            session!.delegate = self
            session!.activate()
        } else {
            NSLog("WatchConnectivity is not supported on this device")
        }
    }
    
    func pushPrinters() {
        do {
            try getSession()?.updateApplicationContext(encodePrinters())
        }
        catch {
            NSLog("Failed to push printers as ApplicationContext. Error: \(error)")
        }
    }

    // MARK: - WCSessionDelegate
    
    /** Called when the session has completed activation. If session state is WCSessionActivationStateNotActivated there will be an error with more details. */
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
    }
    
    
    /** Called when the session can no longer be used to modify or add any new transfers and, all interactive messages will be cancelled, but delegate callbacks for background transfers can still occur. This will happen when the selected watch is being changed. */
    public func sessionDidBecomeInactive(_ session: WCSession) {
        
    }
    
    
    /** Called when all delegate callbacks for the previously selected watch has occurred. The session can be re-activated for the now selected watch using activateSession. */
    public func sessionDidDeactivate(_ session: WCSession) {
        
    }
    
    /** Called on the delegate of the receiver. Will be called on startup if the incoming message caused the receiver to launch. */
    public func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if message["start_print"] != nil {
            // Apple Watch requested to start new print job
            if let file = message["start_print"] as! String? {
                NSLog("Requesting to start printing file: \(file)")
            }
        } else {
            // Unkown request was received
            NSLog("Unknown request was received: \(message)")
        }
        
    }
    
    /** Called on the delegate of the receiver when the sender sends a message that expects a reply. Will be called on startup if the incoming message caused the receiver to launch. */
    public func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        if message["printers"] != nil {
            replyHandler(encodePrinters())
        } else {
            // Unkown request was received
            let reply = ["unknown" : ""]
            replyHandler(reply)
            NSLog("Unknown request for a response was received: \(message)")
        }
    }
    
    /** Called on the delegate of the receiver. Will be called on startup if an applicationContext is available. */
    public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        if applicationContext["selected_printer"] != nil {
            // Apple Watch marked a printer as the new selected on
            if let printer = printerManager.getPrinterByName(name: applicationContext["selected_printer"] as! String) {
                // Update stored printers
                printerManager.changeToDefaultPrinter(printer)
                // Ask octoprintClient to connect to new OctoPrint server
                octoprintClient.connectToServer(printer: printer)
                // Notify listeners of this change
                for delegate in delegates {
                    delegate.defaultPrinterChanged()
                }
            }
        }
    }

    // MARK: - CloudKitPrinterDelegate
    
    func printersUpdated() {
        pushPrinters()
    }
    
    func printerAdded(printer: Printer) {
    }
    
    func printerUpdated(printer: Printer) {
    }
    
    func printerDeleted(printer: Printer) {
    }
    
    // MARK: - Delegates operations
    
    func remove(watchSessionManagerDelegate toRemove: WatchSessionManagerDelegate) {
        delegates.removeAll(where: { $0 === toRemove })
    }

    // MARK: - Private functions
    
    fileprivate func getSession() -> WCSession? {
        if let session = session {
            // Check that Apple Watch is paired and app is installed
            if !session.isPaired {
                print("Apple Watch is not paired")
            } else if !session.isWatchAppInstalled {
                print("WatchKit app is not installed")
            } else {
                return session
            }
        }
        return nil
    }
    
    fileprivate func encodePrinters() -> [String: [[String : Any]]] {
        var printers: [[String : Any]] = []
        for printer in printerManager.getPrinters() {
            let printerDic = ["name": printer.name, "hostname": printer.hostname, "apiKey": printer.apiKey, "isDefault": printer.defaultPrinter] as [String : Any]
            printers.append(printerDic)
        }
        
        NSLog("Encoded printers: \(["printers" : printers])")
        
        return ["printers" : printers]
    }
}
