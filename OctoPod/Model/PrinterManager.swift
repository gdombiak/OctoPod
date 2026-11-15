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
    
    /// Context to use when not running in main thread and using Core Data.
    ///
    /// Each caller gets a sibling context, so a property-level merge policy is
    /// required to preserve values written by other writers to different
    /// Printer properties. If two writers change the same property, the
    /// context saving last wins for that property.
    func newPrivateContext(writer: String = #function) -> NSManagedObjectContext {
        // Create a new background managed object context
        let context = persistentContainer.newBackgroundContext()
        context.name = "PrinterManager.\(writer)"
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

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

    /// Return whether the printer identified by the object URL has PrintTimeGenius installed.
    /// The managed object remains confined to the provided context's queue.
    func isPrintTimeGeniusInstalled(context: NSManagedObjectContext, objectURL: URL) -> Bool {
        var installed = false
        context.performAndWait {
            if let objectID = context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: objectURL),
               let printer = context.object(with: objectID) as? Printer {
                installed = printer.printTimeGeniusInstalled
            }
        }
        return installed
    }
    
    func getPrinters(context: NSManagedObjectContext) -> [Printer] {
        context.performAndWait {
            (try? fetchPrinters(in: context)) ?? []
        }
    }

    /// Call on the context's queue when a failed fetch must be distinguished from an empty store.
    func fetchPrinters(in context: NSManagedObjectContext) throws -> [Printer] {
        let request = NSFetchRequest<Printer>(entityName: "Printer")
        request.sortDescriptors = [NSSortDescriptor(key: "position", ascending: true), NSSortDescriptor(key: "name", ascending: true)]
        return try context.fetch(request)
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
    
    func addPrinter(connectionType: PrinterConnectionType, name: String, hostname: String, apiKey: String, username: String?, password: String?, headers: String?, position: Int16, iCloudUpdate: Bool, modified: Date = Date()) -> Bool {
        let context = newPrivateContext()
        return context.performAndWait {
            let printer = insertPrinter(in: context, isDefault: getDefaultPrinter(context: context) == nil)
            printer.setPrinterConnectionType(connectionType: connectionType)
            printer.name = name
            printer.hostname = hostname
            printer.apiKey = apiKey
            printer.userModified = modified // Track when settings were modified
            printer.position = position
            
            printer.username = username
            printer.password = password
            
            printer.headers = headers
            
            // Mark if printer needs to be updated in iCloud
            printer.iCloudUpdate = iCloudUpdate
            
            return saveObject(printer, context: context)
        }
    }

    /// Prepare a printer on the context's queue so callers can save its identity with its fields.
    func insertPrinter(in context: NSManagedObjectContext, isDefault: Bool) -> Printer {
        let printer = NSEntityDescription.insertNewObject(forEntityName: "Printer", into: context) as! Printer
        printer.defaultPrinter = isDefault
        printer.sdSupport = true
        printer.cameraOrientation = Int16(UIImage.Orientation.up.rawValue)
        printer.invertX = false
        printer.invertY = false
        printer.invertZ = false
        return printer
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
    
    @discardableResult
    func updatePrinter(_ printer: Printer) -> Bool {
        return updatePrinter(printer, context: managedObjectContext)
    }
    
    @discardableResult
    func updatePrinter(_ printer: Printer, context: NSManagedObjectContext) -> Bool {
        switch context.concurrencyType {
        case .mainQueueConcurrencyType:
            // If context runs in main thread then just run this code
            do {
                try context.save()
                return true
            } catch let error as NSError {
                logPrinterSaveError(error, context: context, objectID: printer.objectID)
                return false
            }
        case .privateQueueConcurrencyType, .confinementConcurrencyType:
            // If context runs in a non-main thread then just run this code
            // .confinementConcurrencyType is not used. Delete once removed from Swift
            var saved = false
            context.performAndWait {
                do {
                    try context.save()
                    saved = true
                } catch let error as NSError {
                    self.logPrinterSaveError(error, context: context, objectID: printer.objectID)
                }
            }
            // The view context automatically merges saves from sibling contexts.
            // Do not save or refresh it here: it may have independent UI edits.
            return saved
        @unknown default:
            logUnknownContextConcurrencyType(operation: "updating printer", context: context)
            return false
        }
    }

    private func logUnknownContextConcurrencyType(operation: String, context: NSManagedObjectContext) {
        NSLog("Skipping %@ because the managed object context has an unknown concurrency type. writer=%@", operation, context.name ?? "(unnamed)")
    }

    private func logPrinterSaveError(_ error: NSError, context: NSManagedObjectContext, objectID: NSManagedObjectID) {
        NSLog("%@", Self.printerSaveDiagnostic(error, context: context, objectID: objectID))
    }

    static func printerSaveDiagnostic(_ error: NSError, context: NSManagedObjectContext, objectID: NSManagedObjectID) -> String {
        let details = sanitizedConflictDetails(error)
        return "Error updating printer. writer=\(context.name ?? "(unnamed)") objectID=\(objectID.uriRepresentation().absoluteString) domain=\(error.domain) code=\(error.code) description=\(error.localizedDescription)\(details)"
    }

    private static func sanitizedConflictDetails(_ error: NSError) -> String {
        var conflictDetails: [String] = []
        if let conflicts = error.userInfo[NSPersistentStoreSaveConflictsErrorKey] as? [NSMergeConflict] {
            conflictDetails = conflicts.map { conflict in
                let object = conflict.objectSnapshot ?? [:]
                let cached = conflict.cachedSnapshot ?? [:]
                let persisted = conflict.persistedSnapshot ?? [:]
                let keys = Self.conflictingPrinterPropertyKeys(objectSnapshot: object, cachedSnapshot: cached, persistedSnapshot: persisted)
                return "keys=\(keys)"
            }
        }
        return conflictDetails.isEmpty ? "" : ". Conflicts: \(conflictDetails.joined(separator: "; "))"
    }

    static func conflictingPrinterPropertyKeys(objectSnapshot: [String: Any], cachedSnapshot: [String: Any], persistedSnapshot: [String: Any]) -> [String] {
        let changedInContext = changedPrinterPropertyKeys(current: objectSnapshot, baseline: cachedSnapshot)
        let changedInStore = changedPrinterPropertyKeys(current: persistedSnapshot, baseline: cachedSnapshot)
        return changedInContext.intersection(changedInStore).sorted()
    }

    private static func changedPrinterPropertyKeys(current: [String: Any], baseline: [String: Any]) -> Set<String> {
        return Set(current.keys).union(baseline.keys).filter {
            !coreDataValuesEqual(current[$0], baseline[$0])
        }
    }

    private static func coreDataValuesEqual(_ lhs: Any?, _ rhs: Any?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (lhs?, rhs?):
            return (lhs as? NSObject)?.isEqual(rhs) ?? false
        default:
            return false
        }
    }
    
    // MARK: Generic db operations

    @discardableResult
    func saveObject(_ object: NSManagedObject, context: NSManagedObjectContext) -> Bool {
        switch context.concurrencyType {
        case .mainQueueConcurrencyType:
            do {
                try context.save()
                return true
            } catch let error as NSError {
                logSaveObjectError(error, context: context, objectID: object.objectID)
                return false
            }
        case .privateQueueConcurrencyType, .confinementConcurrencyType:
            var saved = false
            context.performAndWait {
                do {
                    try context.save()
                    saved = true
                } catch let error as NSError {
                    self.logSaveObjectError(error, context: context, objectID: object.objectID)
                }
            }
            return saved
        @unknown default:
            logUnknownContextConcurrencyType(operation: "saving object", context: context)
            return false
        }
    }

    private func logSaveObjectError(_ error: NSError, context: NSManagedObjectContext, objectID: NSManagedObjectID) {
        let details = Self.sanitizedConflictDetails(error)
        NSLog("Error saving object. writer=\(context.name ?? "(unnamed)") objectID=\(objectID.uriRepresentation().absoluteString) domain=\(error.domain) code=\(error.code) description=\(error.localizedDescription)\(details)")
    }
    
    @discardableResult
    func deleteObject(_ object: NSManagedObject, context: NSManagedObjectContext) -> Bool {
        switch context.concurrencyType {
        case .mainQueueConcurrencyType:
            var saved = false
            context.performAndWait {
                let objectID = object.objectID
                context.delete(object)
                do {
                    try context.save()
                    saved = true
                } catch let error as NSError {
                    self.logSaveObjectError(error, context: context, objectID: objectID)
                }
            }
            return saved
        case .privateQueueConcurrencyType, .confinementConcurrencyType:
            var saved = false
            context.performAndWait {
                let objectID = object.objectID
                context.delete(object)
                do {
                    try context.save()
                    saved = true
                } catch let error as NSError {
                    self.logSaveObjectError(error, context: context, objectID: objectID)
                }
            }
            return saved
        @unknown default:
            logUnknownContextConcurrencyType(operation: "deleting object", context: context)
            return false
        }
    }
    
    // MARK: Delete operations

    @discardableResult
    func deletePrinter(_ printer: Printer, context: NSManagedObjectContext) -> Bool {
        context.performAndWait {
            if printer.defaultPrinter {
                do {
                    let remaining = try fetchPrinters(in: context).filter { $0 != printer }
                    let replacement = remaining.first
                    for candidate in remaining where candidate.defaultPrinter != (candidate == replacement) {
                        candidate.defaultPrinter = candidate == replacement
                    }
                } catch {
                    NSLog("Error choosing a default printer before deletion: %@", String(describing: error))
                    return false
                }
            }
            context.delete(printer)
            return updatePrinter(printer, context: context)
        }
    }
    
    func deleteAllPrinters(context: NSManagedObjectContext) throws -> Bool {
        try context.performAndWait {
            let printers = try fetchPrinters(in: context)
            guard !printers.isEmpty else { return false }
            for printer in printers {
                context.delete(printer)
            }
            try context.save()
            return true
        }
    }

    // MARK: CloudKit related operations

    func resetPrintersForiCloud(context: NSManagedObjectContext) throws {
        try context.performAndWait {
            for printer in try fetchPrinters(in: context) {
                printer.recordName = nil
                printer.recordData = nil
                printer.iCloudUpdate = true
            }
            if context.hasChanges { try context.save() }
        }
    }

}
