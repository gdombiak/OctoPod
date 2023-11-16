import Foundation

class Octorelay {
    
    private(set) var id: String
    private(set) var active: Bool
    private(set) var name: String
    
    static func parse(json: NSDictionary) -> Octorelay? {
        // json["active"] is for backward compatibility to API v1
        if let id = json["id"] as? String, let name = json["name"] as? String, let active = (json["status"] ?? json["active"]) as? Bool {
            return Octorelay(id: id, active: active, name: name)
        }
        return nil
    }
    
    private init(id: String, active: Bool, name: String) {
        self.id = id
        self.active = active
        self.name = name
    }
    
    
}
