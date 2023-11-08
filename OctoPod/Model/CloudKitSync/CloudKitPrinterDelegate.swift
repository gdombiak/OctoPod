import Foundation
import CoreData

/// Delegate that will be notified of changes to printers based on iCloud activity
protocol CloudKitPrinterDelegate: AnyObject {
    
    /// Notification that printer information has been updated from iCloud
    /// This could include new printers, updates or deletes
    func printersUpdated()
    
    /// Notification that a given printer has been added from iCloud information
    func printerAdded(printerID: NSManagedObjectID)

    /// Notification that a given printer has been updated from iCloud information
    func printerUpdated(printerID: NSManagedObjectID)

    /// Notification that a given printer has been deleted
    func printerDeleted(printerID: NSManagedObjectID)
    
    /// Notification that user is now logged in/out iCloud
    func iCloudStatusChanged(connected: Bool)    
}

// Make everything optional so implementors of this protocol are not forced to implement everything
extension CloudKitPrinterDelegate {
    func printersUpdated() {}
 
    func printerAdded(printerID: NSManagedObjectID) {}

    func printerUpdated(printerID: NSManagedObjectID) {}

    func printerDeleted(printerID: NSManagedObjectID) {}

    func iCloudStatusChanged(connected: Bool) {}
}
