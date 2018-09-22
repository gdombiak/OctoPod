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
    @NSManaged var wemoplugs: [[String]]?  // Array of an Array with 2 strings (IP Address, Label)
    @NSManaged var domoticzplugs: [[String]]?  // Array of an Array with 2 strings (IP Address, Label)

    struct IPPlug: Equatable {
        var ip: String
        var label: String
        
        var idx: String? // Used by some plugins like Domoticz or Tasmota
        var username: String? // Used by some plugins like Domoticz or Tasmota
        var password: String? // Used by some plugins like Domoticz or Tasmota

        static func ==(lhs: IPPlug, rhs: IPPlug) -> Bool {
            return (lhs.ip == rhs.ip) && (lhs.label == rhs.label) && (lhs.idx == rhs.idx) && (lhs.username == rhs.username) && (lhs.password == rhs.password)
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

    func setTPLinkSmartplugs(plugs: [IPPlug]?) {
        if let newPlugs = plugs {
            var newValues: [[String]] = []
            for newPlug in newPlugs {
                newValues.append(encodeIPPlug(newPlug))
            }
            tpLinkSmartplugs = newValues
        } else {
            tpLinkSmartplugs = nil
        }
    }
    
    func getTPLinkSmartplugs() -> [IPPlug]? {
        if let plugs = tpLinkSmartplugs {
            var result:[IPPlug] = []
            for plug in plugs {
                result.append(decodePlug(encoded: plug))
            }
            return result
        }
        return nil
    }

    func setWemoPlugs(plugs: [IPPlug]?) {
        if let newPlugs = plugs {
            var newValues: [[String]] = []
            for newPlug in newPlugs {
                newValues.append(encodeIPPlug(newPlug))
            }
            wemoplugs = newValues
        } else {
            wemoplugs = nil
        }
    }
    
    func getWemoPlugs() -> [IPPlug]? {
        if let plugs = wemoplugs {
            var result:[IPPlug] = []
            for plug in plugs {
                result.append(decodePlug(encoded: plug))
            }
            return result
        }
        return nil
    }

    func setDomoticzPlugs(plugs: [IPPlug]?) {
        if let newPlugs = plugs {
            var newValues: [[String]] = []
            for newPlug in newPlugs {
                newValues.append(encodeIPPlug(newPlug))
            }
            domoticzplugs = newValues
        } else {
            domoticzplugs = nil
        }
    }
    
    func getDomoticzPlugs() -> [IPPlug]? {
        if let plugs = domoticzplugs {
            var result:[IPPlug] = []
            for plug in plugs {
                result.append(decodePlug(encoded: plug))
            }
            return result
        }
        return nil
    }
    
    fileprivate func encodeIPPlug(_ newPlug: Printer.IPPlug) -> [String] {
        var result = [newPlug.ip, newPlug.label]
        if let idx = newPlug.idx {
            result.append(idx)
        }
        if let username = newPlug.username {
            result.append(username)
        }
        if let password = newPlug.password {
            result.append(password)
        }
        return result
    }
    
    fileprivate func decodePlug(encoded: Array<String>) -> IPPlug {
        let ip = encoded[0]
        let label = encoded[1]
        var idx: String?
        var username: String?
        var password: String?
        if encoded.count > 2 {
            idx = encoded[2]
        }
        if encoded.count > 3 {
            username = encoded[3]
        }
        if encoded.count > 4 {
            password = encoded[4]
        }
        return IPPlug(ip: ip, label: label, idx: idx, username: username, password: password)
    }

}
