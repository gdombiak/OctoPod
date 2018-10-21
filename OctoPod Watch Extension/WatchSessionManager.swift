import Foundation
import WatchConnectivity

class WatchSessionManager: NSObject, WCSessionDelegate {
    
    static let instance = WatchSessionManager()
    
    var session: WCSession?

    // MARK: - WCSession functions

    // Try initiating a connection to the iOS App
    func startSession() {
        if (WCSession.isSupported()) {
            session = WCSession.default
            
            session!.delegate = self
            session!.activate()
        } else {
            print("WatchConnectivity is not supported on this device")
        }
    }
    
    func updateApplicationContext(context: [String : Any]) {
        do {
            try session?.updateApplicationContext(context)
        }
        catch {
            NSLog("Failed to request iOS app to update context \(context). Error: \(error)")
        }
    }
    
    func adsasd() {
        
    }
    
    // MARK: - WCSessionDelegate
    
    /** Called when the session has completed activation. If session state is WCSessionActivationStateNotActivated there will be an error with more details. */
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if activationState == .activated {
            if session.isReachable { // I assume that it is always reachable but just be sure
                // If we never got printers information then request it
                // When printer info changes, iOS app will send printers information using
                // applicationContext so there is no need to fetch it every time a session is activated
                if PrinterManager.instance.printers.isEmpty {
                    // Request list of printers
                    session.sendMessage(["printers": ""], replyHandler: { (reply: [String : Any]) in
                        // Process response from our request. Update list of printers we received
                        PrinterManager.instance.updatePrinters(printers: reply["printers"] as! [[String : Any]])
                    }) { (error: Error) in
                        NSLog("Failed to request printers. Error: \(error)")
                    }
                }
            }
        }
    }
    
    /** Called on the delegate of the receiver. Will be called on startup if an applicationContext is available. */
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        // Application Context contains printers information so update info about printers
        if applicationContext["printers"] != nil {
            PrinterManager.instance.updatePrinters(printers: applicationContext["printers"] as! [[String : Any]])
        }
    }
}
