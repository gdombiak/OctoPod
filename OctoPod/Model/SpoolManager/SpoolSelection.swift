import Foundation

class SpoolSelection {
    var toolNumber: Int?
    var spoolId: Int?
    var spoolCode: String?
    var spoolName: String?
    var spoolWeight: Double?
    var spoolUsed: Double?
    var profileMaterial: String? = "" // Add default value since server does not send a value if not set
    var profileVendor: String?
    
    init(toolNumber: Int? = nil) {
        self.toolNumber = toolNumber
    }
    
    // MARK: - Parse operations
    
    func parse(json: NSDictionary) {
        if let id = json["databaseId"] as? Int {
            spoolId = id
        }
        if let code = json["code"] as? String {
            spoolCode = code
        }
        if let name = json["displayName"] as? String {
            spoolName = name
        }
        if let weight = json["totalWeight"] as? String {
            spoolWeight = Double(weight)
        }
        if let used = json["usedWeight"] as? String {
            spoolUsed = Double(used)
        }
        if let material = json["material"] as? String {
            profileMaterial = material
        }
        if let vendor = json["vendor"] as? String {
            profileVendor = vendor
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
            return "\(name) - \(material) (\(vendor))"
        }
        return NSLocalizedString("No spool selected", comment: "")
    }

    func displayUsage() -> String {
        if let used = spoolUsed, let weight = spoolWeight {
            return "\(Int(used))g / \(Int(weight))g (\(Int(used/weight*100))%)"
        }
        return NSLocalizedString("", comment: "")
    }

    func displayRemaining() -> String {
        if let used = spoolUsed, let weight = spoolWeight {
            let remaining = weight - used
            return "\(Int(remaining))g / \(Int(weight))g (\(Int(remaining/weight*100))%)"
        }
        return NSLocalizedString("", comment: "")
    }
    
    func displayCode() -> String {
        if let code = spoolCode {
            return code
        }
        return NSLocalizedString("", comment: "")
    }
}
