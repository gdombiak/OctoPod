import Foundation
import CoreData

class BLTouch: NSManagedObject {
 
    @NSManaged public var cmdProbeUp: String
    @NSManaged public var cmdProbeDown: String
    @NSManaged public var cmdSelfTest: String
    @NSManaged public var cmdReleaseAlarm: String
    @NSManaged public var cmdProbeBed: String
    @NSManaged public var cmdSaveSettings: String
    @NSManaged public var printer: Printer?
}
