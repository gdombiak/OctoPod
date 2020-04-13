import Foundation
import CoreData

class EnclosureInput: NSManagedObject {
 
    @NSManaged public var type: String
    @NSManaged public var index_id: Int16
    @NSManaged public var label: String
    @NSManaged public var use_fahrenheit: Bool
    @NSManaged public var printer: Printer?

}
