import Foundation
import CoreData

// A Printer (term used in the UI) actually represents an OctoPrint server
class Printer: NSManagedObject {
    
    @NSManaged var name: String
    @NSManaged var hostname: String
    @NSManaged var apiKey: String
    @NSManaged var defaultPrinter: Bool

    @NSManaged var username: String?
    @NSManaged var password: String?

    @NSManaged var sdSupport: Bool
    @NSManaged var cameraOrientation: Int16  // Raw value of UIImageOrientation enum
    @NSManaged var cameras: [String]? // Array that holds URLs to cameras. OctoPrint needs to use MultiCam plugin

    @NSManaged var invertX: Bool  // Control of X is inverted
    @NSManaged var invertY: Bool  // Control of Y is inverted
    @NSManaged var invertZ: Bool  // Control of Z is inverted
}
