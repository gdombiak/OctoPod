import Foundation

protocol WatchSessionManagerDelegate: class {
    
    // Notification that a new default printer has been selected from the Apple Watch app
    func defaultPrinterChanged()
}
