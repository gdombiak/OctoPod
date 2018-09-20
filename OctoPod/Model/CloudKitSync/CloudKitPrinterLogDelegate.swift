import Foundation

// Delegate that gets notified when log of iCloud activity (of printers)
// gets updated
protocol CloudKitPrinterLogDelegate: class {
    
    // Notification that the log has been updated with a new entry
    func logUpdated(newEntry: CloudKitPrinterLogEntry)
}
