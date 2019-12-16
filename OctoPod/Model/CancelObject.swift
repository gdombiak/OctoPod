import Foundation

class CancelObject {
    
    private(set) var active: Bool
    private(set) var cancelled: Bool
    private(set) var id: Int
    private(set) var ignore: Bool
    private(set) var object: String
    
    static func parse(json: NSDictionary) -> CancelObject? {
        if let id = json["id"] as? Int, let object = json["object"] as? String, let cancelled = json["cancelled"] as? Bool, let active = json["active"] as? Bool, let ignore = json["ignore"] as? Bool {
            return CancelObject(id: id, object: object, cancelled: cancelled, active: active, ignore: ignore)
        }
        return nil
    }
    
    /// Returns array with strings that represent objects that cannot be cancelled. Whitespaces are trimmed
    static func parseCancelObjectIgnore(ignored: String?) -> Array<String> {
        if let ignored = ignored {
            return ignored.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        return Array<String>()
    }
    
    private init(id: Int, object: String, cancelled: Bool, active: Bool, ignore: Bool) {
        self.id = id
        self.object = object
        self.cancelled = cancelled
        self.active = active
        self.ignore = ignore
    }
    
    
}
