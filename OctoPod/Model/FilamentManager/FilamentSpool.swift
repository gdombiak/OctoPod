import Foundation

class FilamentSpool {
    var spoolId: Int?
    var spoolName: String?
    var spoolWeight: Double?
    var spoolUsed: Double?
    var profileMaterial: String?
    var profileVendor: String?
    
    // MARK: - Parse operations
    
    func parse(json: NSDictionary) {
        if let id = json["id"] as? Int {
            spoolId = id
        }
        if let name = json["name"] as? String {
            spoolName = name
        }
        if let weight = json["weight"] as? Double {
            spoolWeight = weight
        }
        if let used = json["used"] as? Double {
            spoolUsed = used
        }
        if let profile = json["profile"] as? NSDictionary {
            if let material = profile["material"] as? String {
                profileMaterial = material
            }
            if let vendor = profile["vendor"] as? String {
                profileVendor = vendor
            }
        }
    }
    
    func displaySpool() -> String {
        if let name = spoolName, let used = spoolUsed, let weight = spoolWeight, let material = profileMaterial, let vendor = profileVendor {
            return "\(name) \(Int(weight - used))g - \(material) (\(vendor))"
        }
        return NSLocalizedString("Unknown", comment: "")
    }
}
