import Foundation
import CoreData

// A Printer (term used in the UI) actually represents an OctoPrint server
class Printer: NSManagedObject {
    
    @NSManaged var recordName: String? // Unique identifier of this record in CloudKit
    @NSManaged var recordData: Data? // Encoded data of the iCloud record
    @NSManaged var iCloudUpdate: Bool // Flag that indicates if this record needs to be created/updated in CloudKit
    
    @NSManaged var name: String
    @NSManaged var hostname: String
    @NSManaged var streamUrl: String? // path to the webcam. Info discovered via api/settings
    @NSManaged var apiKey: String
    @NSManaged var defaultPrinter: Bool
    @NSManaged var userModified: Date? // Date when user last modified this settings

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
    
    func getStreamPath() -> String {
        if let path = streamUrl {
            return path
        }
        return "/webcam/?action=stream"
    }
    
    // Returns true if returned getStreamPath() is coming from what OctoPrint reported via /api/settings. False means that it is assumed one
    func isStreamPathFromSettings() -> Bool {
        return streamUrl != nil
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
