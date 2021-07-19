import Foundation
import CoreData

class MultiCamera: NSManagedObject {
 
    @NSManaged public var index_id: Int16  // Starts at 1
    @NSManaged public var name: String
    @NSManaged public var cameraURL: String
    @NSManaged public var cameraOrientation: Int16
    @NSManaged public var streamRatio: String
    @NSManaged public var printer: Printer?

}
