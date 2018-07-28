import Foundation
import UIKit
import CoreData

// Manager of persistent printer information (OctoPrint servers) that are stored in the iPhone
// Printer information (OctoPrint server info) is used for connecting to the server
class PrinterManager {
    var managedObjectContext: NSManagedObjectContext?
    
    init() { }

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

    func getPrinters() -> [Printer] {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Printer.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        if let fetchResults = (try? managedObjectContext!.fetch(fetchRequest)) as? [Printer] {
            return fetchResults
        }
        return []
    }
    
    // MARK: Writing operations
    
    func addPrinter(name: String, hostname: String, apiKey: String, username: String?, password: String?) {
        let printer = NSEntityDescription.insertNewObject(forEntityName: "Printer", into: self.managedObjectContext!) as! Printer
        
        printer.name = name
        printer.hostname = hostname
        printer.apiKey = apiKey
        
        printer.username = username
        printer.password = password
        
        printer.sdSupport = true // Assume that printer supports SD card. Will get updated later with actual value
        printer.cameraOrientation = Int16(UIImageOrientation.up.rawValue) // Assume no flips or rotations for camera. Will get updated later with actual value

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
        } catch let error as NSError {
            NSLog("Error adding printer \(error)")
        }
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
            NSLog("Error updating printer \(error)")
        }
    }
    
    // MARK: Delete operations

    func deletePrinter(_ printer: Printer) {
        managedObjectContext!.delete(printer)
        
        do {
            try managedObjectContext!.save()
        } catch let error as NSError {
            NSLog("Error deleting printer \(error)")
        }
        
        if printer.defaultPrinter {
            // Find any printer and make it the default printer
            for printer in getPrinters() {
                changeToDefaultPrinter(printer)
                break
            }
        }
    }

}
