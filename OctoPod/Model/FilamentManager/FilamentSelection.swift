import Foundation

class FilamentSelection {
    var toolNumber: Int?
    var spoolId: Int?
    var spoolName: String?
    var spoolWeight: Double?
    var spoolUsed: Double?
    var profileMaterial: String?
    var profileVendor: String?
    
    // MARK: - Parse operations

    func parse(json: NSDictionary) {
        if let tool = json["tool"] as? Int {
            toolNumber = tool
        }
        if let spool = json["spool"] as? NSDictionary {
            if let id = spool["id"] as? Int {
                spoolId = id
            }
            if let name = spool["name"] as? String {
                spoolName = name
            }
            if let weight = spool["weight"] as? Double {
                spoolWeight = weight
            }
            if let used = spool["used"] as? Double {
                spoolUsed = used
            }
            if let profile = spool["profile"] as? NSDictionary {
                if let material = profile["material"] as? String {
                    profileMaterial = material
                }
                if let vendor = profile["vendor"] as? String {
                    profileVendor = vendor
                }
            }
        }
    }
    
    func displayTool() -> String {
        if let extruder = toolNumber {
            return "\(NSLocalizedString("Extruder", comment: "")) \(extruder)"
        }
        return "\(NSLocalizedString("Extruder", comment: "")) ???"
    }
    
    func displaySelection() -> String {
        if let name = spoolName, let material = profileMaterial, let vendor = profileVendor {
            return "\(name) \(material) (\(vendor))"
        }
        return NSLocalizedString("Unknown", comment: "")
    }

    func displayUsage() -> String {
        if let used = spoolUsed, let weight = spoolWeight {
            return "\(Int(used))g / \(Int(weight))g (\(Int(used/weight*100))%)"
        }
        return NSLocalizedString("Unknown", comment: "")
    }
}
