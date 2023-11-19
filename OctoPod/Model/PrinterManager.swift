import Foundation
import UIKit
import CoreData

/// Manager of persistent printer information (OctoPrint servers) that are stored in the iPhone
/// Printer information (OctoPrint server info) is used for connecting to the server
class PrinterManager {
    let managedObjectContext: NSManagedObjectContext // Main Queue. Should only be used by Main thread
    let persistentContainer: NSPersistentContainer // Persistent Container for the entire app

    init(managedObjectContext: NSManagedObjectContext, persistentContainer: NSPersistentContainer) {
        self.managedObjectContext = managedObjectContext
        self.persistentContainer = persistentContainer
    }

    // MARK: Private context operations
    
    /// Context to use when not running in main thread and using Core Data
    func newPrivateContext() -> NSManagedObjectContext {
        // Create a new background managed object context
        let context = persistentContainer.newBackgroundContext()

        // If needed, ensure the background context stays
        // up to date with changes from the parent
        context.automaticallyMergesChangesFromParent = true

        return context
    }

    /// Context to use for Core Data depending on thread being used
    func safePrivateContext() -> NSManagedObjectContext {
        return Thread.current.isMainThread ? managedObjectContext : newPrivateContext()
    }

    // MARK: Reading operations

    func getDefaultPrinter() -> Printer? {
        if !Thread.current.isMainThread {
            NSLog("**** POTENTIAL APP CRASH: Using CoreData from non-main thread using objectContext for main")
        }
        return getDefaultPrinter(context: managedObjectContext)
    }

    func getDefaultPrinter(context: NSManagedObjectContext) -> Printer? {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Printer.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "defaultPrinter = YES")
        
        var result: Printer?
        context.performAndWait {
            if let fetchResults = (try? context.fetch(fetchRequest)) as? [Printer] {
                if fetchResults.count > 0 {
                    result = fetchResults[0]
                }
            }
        }
        return result
    }

    /// Fetch default printer using provided core data context and execute provided completion block in the same thread that fetched default printer
    func getDefaultPrinter(context: NSManagedObjectContext, completion: (Printer?) -> Void)  {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Printer.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "defaultPrinter = YES")
        
        context.performAndWait {
            if let fetchResults = (try? context.fetch(fetchRequest)) as? [Printer] {
                if fetchResults.count > 0 {
                    completion(fetchResults[0])
                } else {
                    completion(nil)
                }
            } else {
                completion(nil)
            }
        }
    }

    /// Get a printer by its record name. A record name is the PK
    /// used by CloudKit for each record
    func getPrinterByRecordName(recordName: String) -> Printer? {
        return getPrinterByName(context: managedObjectContext, name: recordName)
    }

    /// Get a printer by its record name. A record name is the PK
    /// used by CloudKit for each record
    func getPrinterByRecordName(context: NSManagedObjectContext, recordName: String) -> Printer? {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Printer.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "recordName = %@", recordName)
        
        var result: Printer?
        context.performAndWait {
            if let fetchResults = (try? context.fetch(fetchRequest)) as? [Printer] {
                if fetchResults.count > 0 {
                    result = fetchResults[0]
                }
            }
        }
        return result
    }

    func getPrinterByName(name: String) -> Printer? {
        return getPrinterByName(context: managedObjectContext, name: name)
    }

    func getPrinterByName(context: NSManagedObjectContext, name: String) -> Printer? {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Printer.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name = %@", name)
        
        var result: Printer?
        context.performAndWait {
            if let fetchResults = (try? context.fetch(fetchRequest)) as? [Printer] {
                if fetchResults.count > 0 {
                    result = fetchResults[0]
                }
            }
        }

        return result
    }

    func getPrinterByObjectURL(url: URL) -> Printer? {
        return getPrinterByObjectURL(context: managedObjectContext, url: url)
    }
    
    func getPrinterByObjectURL(context: NSManagedObjectContext, url: URL) -> Printer? {
        if let objectID = context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url) {
            var result: Printer?
            context.performAndWait {
                if let printer = context.object(with: objectID) as? Printer {
                    result = printer
                }
            }
            return result
        }
        return nil
    }
    
    /// Fetch requested printer using provided core data context and execute provided completion block in the same thread that fetched requested printer
    func getPrinterByObjectURL(context: NSManagedObjectContext, url: URL, completion: (Printer?) -> Void)  {
        if let objectID = context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url) {
            context.performAndWait {
                if let printer = context.object(with: objectID) as? Printer {
                    completion(printer)
                } else {
                    completion(nil)
                }
            }
        } else {
            completion(nil)
        }
    }
    
    func getPrinters(context: NSManagedObjectContext) -> [Printer] {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Printer.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "position", ascending: true), NSSortDescriptor(key: "name", ascending: true)]
        
        var results: [Printer] = []
        context.performAndWait {
            if let fetchResults = (try? context.fetch(fetchRequest)) as? [Printer] {
                results = fetchResults
            }
       }
        return results
    }
    
    /// Fetch all printers using provided core data context and execute provided completion block in the same thread that fetched the printers
    func getPrinters(context: NSManagedObjectContext, completion: ([Printer]) -> Void) {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Printer.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "position", ascending: true), NSSortDescriptor(key: "name", ascending: true)]
        
        context.performAndWait {
            if let fetchResults = (try? context.fetch(fetchRequest)) as? [Printer] {
                completion(fetchResults)
            } else {
                completion([])
            }
       }
    }
    
    func getPrinters() -> [Printer] {
        return getPrinters(context: managedObjectContext)
    }
    
    // MARK: Writing operations
    
    func addPrinter(connectionType: PrinterConnectionType, name: String, hostname: String, apiKey: String, username: String?, password: String?, position: Int16, iCloudUpdate: Bool, modified: Date = Date()) -> Bool {
        let context = newPrivateContext()
        var saved = false
        context.performAndWait {
            let printer = NSEntityDescription.insertNewObject(forEntityName: "Printer", into: context) as! Printer
            
            printer.setPrinterConnectionType(connectionType: connectionType)
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
            if let _ = getDefaultPrinter(context: context) {
                // We found an existing default printer
                printer.defaultPrinter = false
            } else {
                // No default printer was found so make this new printer the default one
                printer.defaultPrinter = true
            }
            saved = saveObject(printer, context: context)
        }

        return saved
    }
    
    /// Make sure that printer was loaded with the provided context
    func addEnclosureInput(index: Int16, type: String, label: String, useFahrenheit: Bool, context: NSManagedObjectContext, printer: Printer) -> Bool {
        let enclosureInput = NSEntityDescription.insertNewObject(forEntityName: "EnclosureInput", into: context) as! EnclosureInput
        enclosureInput.index_id = index
        enclosureInput.type = type
        enclosureInput.label = label
        enclosureInput.use_fahrenheit = useFahrenheit
        enclosureInput.printer = printer
        // Persist created EnclosureInput
        return saveObject(enclosureInput, context: context)
    }
    
    func addEnclosureOutput(index: Int16, type: String, label: String, context: NSManagedObjectContext, printer: Printer) -> Bool {
        let enclosureOutput = NSEntityDescription.insertNewObject(forEntityName: "EnclosureOutput", into: context) as! EnclosureOutput
        enclosureOutput.index_id = index
        enclosureOutput.type = type
        enclosureOutput.label = label
        enclosureOutput.printer = printer
        // Persist created EnclosureOutput
        return saveObject(enclosureOutput, context: context)
    }
    
    func addMultiCamera(index: Int16, name: String, cameraURL: String, cameraOrientation: Int16, streamRatio: String, context: NSManagedObjectContext, printer: Printer) -> Bool {
        let multiCamera = NSEntityDescription.insertNewObject(forEntityName: "MultiCamera", into: context) as! MultiCamera
        multiCamera.index_id = index
        multiCamera.name = name
        multiCamera.cameraURL = cameraURL
        multiCamera.cameraOrientation = cameraOrientation
        multiCamera.streamRatio = streamRatio
        multiCamera.printer = printer
        // Persist created MultiCamera
        return saveObject(multiCamera, context: context)
    }
    
    func addBLTouch(cmdProbeUp: String, cmdProbeDown: String, cmdSelfTest: String, cmdReleaseAlarm: String, cmdProbeBed: String, cmdSaveSettings: String, context: NSManagedObjectContext, printer: Printer) -> Bool {
        let blTouch = NSEntityDescription.insertNewObject(forEntityName: "BLTouch", into: context) as! BLTouch
        blTouch.cmdProbeUp = cmdProbeUp
        blTouch.cmdProbeDown = cmdProbeDown
        blTouch.cmdSelfTest = cmdSelfTest
        blTouch.cmdReleaseAlarm = cmdReleaseAlarm
        blTouch.cmdProbeBed = cmdProbeBed
        blTouch.cmdSaveSettings = cmdSaveSettings
        blTouch.printer = printer
        // Persist created BLTouch
        return saveObject(blTouch, context: context)
    }
    
    /// Make sure to call this only from main thread
    func changeToDefaultPrinter(_ printer: Printer) {
        changeToDefaultPrinter(printer, context: managedObjectContext)
    }
    
    fileprivate func changeToDefaultPrinter(_ printer: Printer, context: NSManagedObjectContext) {
        context.performAndWait {
            // Check if there is already a default Printer
            if let currentDefaultPrinter: Printer = self.getDefaultPrinter(context: context) {
                // Current default printer is no longer the default one
                currentDefaultPrinter.defaultPrinter = false
                self.updatePrinter(currentDefaultPrinter, context: context)
            }

            // Make this printer the default one
            let newDefaultPrinter = context.object(with: printer.objectID) as! Printer
            newDefaultPrinter.defaultPrinter = true
            updatePrinter(newDefaultPrinter, context: context)
        }
    }
    
    func updatePrinter(_ printer: Printer) {
        updatePrinter(printer, context: managedObjectContext)
    }
    
    func updatePrinter(_ printer: Printer, context: NSManagedObjectContext) {
        switch context.concurrencyType {
        case .mainQueueConcurrencyType:
            // If context runs in main thread then just run this code
            do {
                try managedObjectContext.save()
            } catch let error as NSError {
                NSLog("Error updating printer \(printer.hostname). Error: \(error)")
            }
        case .privateQueueConcurrencyType, .confinementConcurrencyType:
            // If context runs in a non-main thread then just run this code
            // .confinementConcurrencyType is not used. Delete once removed from Swift
            context.performAndWait {
                do {
                    try context.save()
                } catch {
                    NSLog("Error updating printer \(error)")
                }
            }
            managedObjectContext.performAndWait {
                do {
                    try managedObjectContext.save()
                    // Refresh object in main context
                    let toRefresh = try managedObjectContext.existingObject(with: printer.objectID)
                    managedObjectContext.refresh(toRefresh, mergeChanges: false)
                } catch {
                    NSLog("Error updating printer \(error). Id: \(printer.objectID)")
                }
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
//                NSLog("** Saving object: \(object.hash) with managed context: \(managedObjectContext) in thread: \(Thread.current). Id: \(object.objectID)")
                try managedObjectContext.save()
                saved = true
            } catch let error as NSError {
                NSLog("Error saving object \(object). Error: \(error)")
            }
        case .privateQueueConcurrencyType, .confinementConcurrencyType:
            // If context runs in a non-main thread then just run this code
            // .confinementConcurrencyType is not used. Delete once removed from Swift
            context.performAndWait {
                do {
                    try context.save()
                } catch {
                    NSLog("Error saving object \(error). Id: \(object.objectID)")
                }
            }
            managedObjectContext.performAndWait {
                do {
                    try managedObjectContext.save()
                    saved = true
                    // Refresh object in main context
                    let toRefresh = try managedObjectContext.existingObject(with: object.objectID)
                    managedObjectContext.refresh(toRefresh, mergeChanges: false)
                } catch {
                    NSLog("Error saving object \(error). Id: \(object.objectID)")
                }
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
                try managedObjectContext.save()
            } catch let error as NSError {
                NSLog("Error deleting object \(object). Error: \(error)")
            }
        case .privateQueueConcurrencyType, .confinementConcurrencyType:
            // If context runs in a non-main thread then just run this code
            // .confinementConcurrencyType is not used. Delete once removed from Swift
            do {
                try context.save()
                managedObjectContext.performAndWait {
                    do {
                        try managedObjectContext.save()
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

        context.performAndWait {
            do {
                try context.execute(deleteRequest)
                // Reset the Managed Object Context
                context.reset()
                managedObjectContext.reset()
            }
            catch let error as NSError {
                NSLog("Error deleting all printers. Error:\(error)")
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
                try managedObjectContext.save()
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
                    managedObjectContext.performAndWait {
                        do {
                            try managedObjectContext.save()
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
