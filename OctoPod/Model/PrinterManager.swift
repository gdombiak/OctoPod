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
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    // MARK: Reading operations

    func getDefaultPrinter() -> Printer? {
        return getDefaultPrinter(context: managedObjectContext!)
    }

    func getDefaultPrinter(context: NSManagedObjectContext) -> Printer? {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Printer.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "defaultPrinter = YES")
        
        if let fetchResults = (try? context.fetch(fetchRequest)) as? [Printer] {
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

    func getPrinterByObjectURL(url: URL) -> Printer? {
        if let objectID = managedObjectContext?.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url) {
            if let printer = managedObjectContext?.object(with: objectID) as? Printer {
                return printer
            }
        }
        return nil
    }
    
    func getPrinters(context: NSManagedObjectContext) -> [Printer] {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Printer.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "position", ascending: true), NSSortDescriptor(key: "name", ascending: true)]
        
        if let fetchResults = (try? context.fetch(fetchRequest)) as? [Printer] {
            return fetchResults
        }
        return []
    }
    
    func getPrinters() -> [Printer] {
        return getPrinters(context: managedObjectContext!)
    }
    
    // MARK: Writing operations
    
    func addPrinter(name: String, hostname: String, apiKey: String, username: String?, password: String?, position: Int16, iCloudUpdate: Bool, modified: Date = Date()) -> Bool {
        let context = newPrivateContext()
        let printer = NSEntityDescription.insertNewObject(forEntityName: "Printer", into: context) as! Printer
        
        printer.name = name
        printer.hostname = hostname
        printer.apiKey = apiKey
        printer.userModified = modified // Track when settings were modified
        printer.position = position
        
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

        return saveObject(printer, context: context)
    }
    
    /// Make sure that printer was loaded with the provided context
    func addEnclosureInput(index: Int16, type: String, label: String, useFahrenheit: Bool, context: NSManagedObjectContext, printer: Printer) -> Bool {
        let enclosureInput = NSEntityDescription.insertNewObject(forEntityName: "EnclosureInput", into: context) as! EnclosureInput
        enclosureInput.index_id = index
        enclosureInput.type = type
        enclosureInput.label = label
        enclosureInput.use_fahrenheit = useFahrenheit
        enclosureInput.printer = printer
        // Persist updated EnclosureInput
        return saveObject(enclosureInput, context: context)
    }
    
    func addEnclosureOutput(index: Int16, type: String, label: String, context: NSManagedObjectContext, printer: Printer) -> Bool {
        let enclosureOutput = NSEntityDescription.insertNewObject(forEntityName: "EnclosureOutput", into: context) as! EnclosureOutput
        enclosureOutput.index_id = index
        enclosureOutput.type = type
        enclosureOutput.label = label
        enclosureOutput.printer = printer
        // Persist updated EnclosureOutput
        return saveObject(enclosureOutput, context: context)
    }
    
    /// Make sure to call this only from main thread
    func changeToDefaultPrinter(_ printer: Printer) {
        changeToDefaultPrinter(printer, context: managedObjectContext!)
    }
    
    func changeToDefaultPrinter(_ printer: Printer, context: NSManagedObjectContext) {
        // Check if there is already a default Printer
        if let currentDefaultPrinter: Printer = getDefaultPrinter(context: context) {
            // Current default printer is no longer the default one
            currentDefaultPrinter.defaultPrinter = false
            updatePrinter(currentDefaultPrinter, context: context)
        }
        // Make this printer the default one
        printer.defaultPrinter = true
        updatePrinter(printer, context: context)
    }
    
    func updatePrinter(_ printer: Printer) {
        updatePrinter(printer, context: managedObjectContext!)
    }
    
    func updatePrinter(_ printer: Printer, context: NSManagedObjectContext) {
        switch context.concurrencyType {
        case .mainQueueConcurrencyType:
            // If context runs in main thread then just run this code
            do {
                try managedObjectContext!.save()
            } catch let error as NSError {
                NSLog("Error updating printer \(printer.hostname). Error: \(error)")
            }
        case .privateQueueConcurrencyType, .confinementConcurrencyType:
            // If context runs in a non-main thread then just run this code
            // .confinementConcurrencyType is not used. Delete once removed from Swift
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
    
    // MARK: Generic db operations

    func saveObject(_ object: NSManagedObject, context: NSManagedObjectContext) -> Bool {
        var saved = false
        switch context.concurrencyType {
        case .mainQueueConcurrencyType:
            // If context runs in main thread then just run this code
            do {
                try managedObjectContext!.save()
                saved = true
            } catch let error as NSError {
                NSLog("Error saving object \(object). Error: \(error)")
            }
        case .privateQueueConcurrencyType, .confinementConcurrencyType:
            // If context runs in a non-main thread then just run this code
            // .confinementConcurrencyType is not used. Delete once removed from Swift
            do {
                try context.save()
                managedObjectContext!.performAndWait {
                    do {
                        try managedObjectContext!.save()
                        saved = true
                    } catch {
                        NSLog("Error saving object \(error)")
                    }
                }
            } catch {
                NSLog("Error saving object \(error)")
            }
        }
        return saved
    }
    
    func deleteObject(_ object: NSManagedObject, context: NSManagedObjectContext) {
        // Delete object from context
        context.delete(object)
        // Save context
        switch context.concurrencyType {
        case .mainQueueConcurrencyType:
            // If context runs in main thread then just run this code
            do {
                try managedObjectContext!.save()
            } catch let error as NSError {
                NSLog("Error deleting object \(object). Error: \(error)")
            }
        case .privateQueueConcurrencyType, .confinementConcurrencyType:
            // If context runs in a non-main thread then just run this code
            // .confinementConcurrencyType is not used. Delete once removed from Swift
            do {
                try context.save()
                managedObjectContext!.performAndWait {
                    do {
                        try managedObjectContext!.save()
                    } catch {
                        NSLog("Error deleting object \(error)")
                    }
                }
            } catch {
                NSLog("Error deleting object \(error)")
            }
        }
    }
    
    // MARK: Delete operations

    func deletePrinter(_ printer: Printer, context: NSManagedObjectContext) {
        context.delete(printer)
        
        updatePrinter(printer, context: context)
        
        if printer.defaultPrinter {
            // Find any printer and make it the default printer
            for printer in getPrinters(context: context) {
                changeToDefaultPrinter(printer, context: context)
                break
            }
        }
    }
    
    func deleteAllPrinters(context: NSManagedObjectContext) {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Printer")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        do {
            try context.execute(deleteRequest)
            // Reset the Managed Object Context
            context.reset()
            managedObjectContext?.reset()
        }
        catch let error as NSError {
            NSLog("Error deleting all printers. Error:\(error)")
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
