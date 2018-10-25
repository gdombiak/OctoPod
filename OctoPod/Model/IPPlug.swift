import Foundation

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

