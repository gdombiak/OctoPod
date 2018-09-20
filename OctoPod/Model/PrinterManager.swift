import Foundation
import UIKit
import CoreData

// Manager of persistent printer information (OctoPrint servers) that are stored in the iPhone
// Printer information (OctoPrint server info) is used for connecting to the server
class PrinterManager {
    var managedObjectContext: NSManagedObjectContext? // Main Queue. Should only be used by Main thread
    
    init() { }

    // MARK: Private context operations
    
    // Context to use when not running in main thread and using Core Data
    func newPrivateContext() -> NSManagedObjectContext {
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.parent = managedObjectContext!
        return context
    }

    // MARK: Reading operations

    func getDefaultPrinter() -> Printer? {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Printer.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "defaultPrinter = YES")
        
        if let fetchResults = (try? managedObjectContext!.fetch(fetchRequest)) as? [Printer] {
            if fetchResults.count == 0 {
                return nil
            }
            return fetchResults[0]
        }
        return nil
    }

    // Get a printer by its record name. A record name is the PK
    // used by CloudKit for each record
    func getPrinterByRecordName(recordName: String) -> Printer? {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Printer.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "recordName = %@", recordName)
        
        if let fetchResults = (try? managedObjectContext!.fetch(fetchRequest)) as? [Printer] {
            if fetchResults.count == 0 {
                return nil
            }
            return fetchResults[0]
        }
        return nil
    }

    func getPrinterByName(name: String) -> Printer? {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Printer.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name = %@", name)
        
        if let fetchResults = (try? managedObjectContext!.fetch(fetchRequest)) as? [Printer] {
            if fetchResults.count == 0 {
                return nil
            }
            return fetchResults[0]
        }
        return nil
    }

    func getPrinters(context: NSManagedObjectContext) -> [Printer] {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Printer.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        if let fetchResults = (try? context.fetch(fetchRequest)) as? [Printer] {
            return fetchResults
        }
        return []
    }
    
    func getPrinters() -> [Printer] {
        return getPrinters(context: managedObjectContext!)
    }
    
    // MARK: Writing operations
    
    func addPrinter(name: String, hostname: String, apiKey: String, username: String?, password: String?, iCloudUpdate: Bool, modified: Date = Date()) -> Printer? {
        let printer = NSEntityDescription.insertNewObject(forEntityName: "Printer", into: self.managedObjectContext!) as! Printer
        
        printer.name = name
        printer.hostname = hostname
        printer.apiKey = apiKey
        printer.userModified = modified // Track when settings were modified
        
        printer.username = username
        printer.password = password
        
        // Mark if printer needs to be updated in iCloud
        printer.iCloudUpdate = iCloudUpdate
        
        printer.sdSupport = true // Assume that printer supports SD card. Will get updated later with actual value
        printer.cameraOrientation = Int16(UIImage.Orientation.up.rawValue) // Assume no flips or rotations for camera. Will get updated later with actual value

        printer.invertX = false // Assume control of X axis is not inverted. Will get updated later with actual value
        printer.invertY = false // Assume control of Y axis is not inverted. Will get updated later with actual value
        printer.invertZ = false // Assume control of Z axis is not inverted. Will get updated later with actual value

        // Check if there is already a default Printer
        if let _ = getDefaultPrinter() {
            // We found an existing default printer
            printer.defaultPrinter = false
        } else {
            // No default printer was found so make this new printer the default one
            printer.defaultPrinter = true
        }
        
        do {
            try managedObjectContext!.save()
            return printer
        } catch let error as NSError {
            NSLog("Error adding printer \(printer.hostname). Error:\(error)")
        }
        return nil
    }
    
    func changeToDefaultPrinter(_ printer: Printer) {
        // Check if there is already a default Printer
        if let currentDefaultPrinter: Printer = getDefaultPrinter() {
            // Current default printer is no longer the default one
            currentDefaultPrinter.defaultPrinter = false
            updatePrinter(currentDefaultPrinter)
        }
        // Make this printer the default one
        printer.defaultPrinter = true
        updatePrinter(printer)
    }
    
    func updatePrinter(_ printer: Printer) {
        do {
            try managedObjectContext!.save()
        } catch let error as NSError {
            NSLog("Error updating printer \(printer.hostname). Error: \(error)")
        }
    }
    
    // MARK: Delete operations

    func deletePrinter(_ printer: Printer) {
        managedObjectContext!.delete(printer)
        
        do {
            try managedObjectContext!.save()
        } catch let error as NSError {
            NSLog("Error deleting printer \(printer.hostname). Error:\(error)")
        }
        
        if printer.defaultPrinter {
            // Find any printer and make it the default printer
            for printer in getPrinters() {
                changeToDefaultPrinter(printer)
                break
            }
        }
    }
    
    // MARK: CloudKit related operations
    
    func resetPrintersForiCloud(context: NSManagedObjectContext) {
        switch context.concurrencyType {
        case .mainQueueConcurrencyType:
            // If context runs in main thread then just run this code
            do {
                for printer in getPrinters() {
                    printer.recordName = nil
                    printer.recordData = nil
                    printer.iCloudUpdate = true
                }
                try managedObjectContext!.save()
            } catch let error as NSError {
                NSLog("Error updating printer \(error)")
            }
        case .privateQueueConcurrencyType, .confinementConcurrencyType:
            // If context runs in a non-main thread then just run this code
            // .confinementConcurrencyType is not used. Delete once removed from Swift
            context.performAndWait {
                for printer in getPrinters(context: context) {
                    printer.recordName = nil
                    printer.recordData = nil
                    printer.iCloudUpdate = true
                }
                
                do {
                    try context.save()
                    managedObjectContext!.performAndWait {
                        do {
                            try managedObjectContext!.save()
                        } catch {
                            NSLog("Error updating printer \(error)")
                        }
                    }
                } catch {
                    NSLog("Error updating printer \(error)")
                }
            }
        }
    }
}
