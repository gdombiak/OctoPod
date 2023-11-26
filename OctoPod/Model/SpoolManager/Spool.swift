import Foundation

class Spool {
    var spoolId: Int?
    var spoolCode: String?
    var spoolName: String?
    var spoolWeight: Double?
    var spoolUsed: Double?
    var profileMaterial: String? = ""
    var profileVendor: String?
    
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
    
    func displaySpool() -> String {
        if let name = spoolName, let used = spoolUsed, let weight = spoolWeight, let vendor = profileVendor {
            return "\(name) \(Int(weight - used))g - \(profileMaterial ?? "") (\(vendor))"
        }
        return NSLocalizedString("Unknown", comment: "")
    }
}
