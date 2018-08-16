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
    
    // Track if the following plugins are installed and configured
    @NSManaged var psuControlInstalled: Bool
    @NSManaged var tpLinkSmartplugs: [[String]]?  // Array of an Array with 2 strings (IP Address, Label)
    
    struct TPLinkSmartplug: Equatable {
        var ip: String
        var label: String

        static func ==(lhs: TPLinkSmartplug, rhs: TPLinkSmartplug) -> Bool {
            return (lhs.ip == rhs.ip) && (lhs.label == rhs.label)
        }
    }
    
    func setTPLinkSmartplugs(plugs: [TPLinkSmartplug]?) {
        if let newPlugs = plugs {
            var newValues: [[String]] = []
            for newPlug in newPlugs {
                newValues.append([newPlug.ip, newPlug.label])
            }
            tpLinkSmartplugs = newValues
        } else {
            tpLinkSmartplugs = nil
        }
    }
    
    func getTPLinkSmartplugs() -> [TPLinkSmartplug]? {
        if let plugs = tpLinkSmartplugs {
            var result:[TPLinkSmartplug] = []
            for plug in plugs {
                result.append(TPLinkSmartplug(ip: plug[0], label: plug[1]))
            }
            return result
        }
        return nil
    }
}
