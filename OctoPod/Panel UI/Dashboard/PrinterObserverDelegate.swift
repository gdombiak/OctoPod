import Foundation

protocol PrinterObserverDelegate {
    
    /// Printer or print job information has changed so refresh information
    func refreshItem(row: Int, printerObserver: PrinterObserver)
    
    /// Notification with raw events with print job information
    func currentStateUpdated(row: Int, event: CurrentStateEvent)
}

// Make all messages optional
extension PrinterObserverDelegate {
    
    func refreshItem(row: Int, printerObserver: PrinterObserver) {}

    func currentStateUpdated(row: Int, event: CurrentStateEvent) {}
}
