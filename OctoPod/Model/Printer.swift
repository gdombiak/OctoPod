import Foundation
import CoreData

class Printer: NSManagedObject {
    
    @NSManaged var name: String
    @NSManaged var hostname: String
    @NSManaged var apiKey: String
    @NSManaged var defaultPrinter: Bool

    @NSManaged var username: String?
    @NSManaged var password: String?
}
