import Foundation

/// Delegate that will be notified of changes to printers based on iCloud activity
protocol CloudKitPrinterDelegate: AnyObject {
    
    /// Notification that printer information has been updated from iCloud
    /// This could include new printers, updates or deletes
    func printersUpdated()
    
    /// Notification that a given printer has been added from iCloud information
    func printerAdded(printer: Printer)

    /// Notification that a given printer has been updated from iCloud information
    func printerUpdated(printer: Printer)

    /// Notification that a given printer has been deleted
    func printerDeleted(printer: Printer)
    
    /// Notification that user is now logged in/out iCloud
    func iCloudStatusChanged(connected: Bool)    
}
