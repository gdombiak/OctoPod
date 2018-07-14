import Foundation

class PrintFile {
    
    var display: String?
    var name: String?
    var path: String?
    var type: String?

    var origin: String?
    
    var size: Int?

    var estimatedPrintTime: Double?
    var date: Date?
    
    // Returns true if file can be sent to be printed
    func canBePrinted() -> Bool {
        return type == "machinecode"
    }
    
    func canBeDeleted() -> Bool {
        return type != "folder"
    }

    func displayOrigin() -> String {
        if let currentOrigin = origin {
            if currentOrigin == "local" {
                return "Octoprint"
            } else if currentOrigin == "sdcard" {
                return "SD Card"
            }
        }
        return "Unknown"
    }
    
    func displayType() -> String {
        if let currentOrigin = origin {
            if currentOrigin == "model" {
                return "Model"
            } else if currentOrigin == "machinecode" {
                return "Code"
            } else if currentOrigin == "folder" {
                return "Folder"
            }
        }
        return "Unknown"
    }
    
    func displaySize() -> String {
        if let currentSize = size {
            let bcf = ByteCountFormatter()
            bcf.allowedUnits = [.useKB, .useMB]
            bcf.countStyle = .file
            return bcf.string(fromByteCount: Int64(currentSize))
        }
        return ""
    }
    
    // MARK: - Parse operations

    func parse(json: NSDictionary) {
        if let newDisplay = json["display"] as? String {
            display = newDisplay
        }
        if let newName = json["name"] as? String {
            name = newName
        }
        if let newPath = json["path"] as? String {
            path = newPath
        }
        if let newType = json["type"] as? String {
            type = newType
        }
        if let newOrigin = json["origin"] as? String {
            origin = newOrigin
        }
        if let newSize = json["size"] as? Int {
            size = newSize
        }
        if let gcodeAnalysis = json["gcodeAnalysis"] as? NSDictionary {
            if let newPrintTime = gcodeAnalysis["estimatedPrintTime"] as? Double {
                estimatedPrintTime = newPrintTime
            }
        }
        if let newDate = json["date"] as? Double {
            date = Date(timeIntervalSince1970: newDate)
        }
    }
}
