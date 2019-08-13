import Foundation

class TempHistory {
    
    private let MAX_HISTORY_SIZE = 400

    struct Temp {
        // Time when temps were measured
        var tempTime: Int?

        // Bed temperatures
        var bedTempActual: Double?
        var bedTempTarget: Double?
        
        // Extruder 0 temperatures
        var tool0TempActual: Double?
        var tool0TempTarget: Double?
        
        // Extruder 1 temperatures (if present)
        var tool1TempActual: Double?
        var tool1TempTarget: Double?

        // Extruder 2 temperatures (if present)
        var tool2TempActual: Double?
        var tool2TempTarget: Double?
        
        // Extruder 3 temperatures (if present)
        var tool3TempActual: Double?
        var tool3TempTarget: Double?
        
        // Extruder 4 temperatures (if present)
        var tool4TempActual: Double?
        var tool4TempTarget: Double?
        
        // Chamber temperatures (if present)
        var chamberTempActual: Double?
        var chamberTempTarget: Double?
        
        mutating func parseTemps(temp: NSDictionary, sharedNozzle: Bool) {
            if let bed = temp["bed"] as? NSDictionary {
                bedTempActual = bed["actual"] as? Double
                bedTempTarget = bed["target"] as? Double
            }
            if let tool = temp["tool0"] as? NSDictionary {
                tool0TempActual = tool["actual"] as? Double
                tool0TempTarget = tool["target"] as? Double
            }
            // Parse temp of other extruders if nozzle is not being shared
            // MMU2 has 5 extruders but a shared nozzle so there is actually
            // only 1 temp to show. However, moving extruder will show all
            // available extruders. Printer Profile in OctoPrint is where you
            // can specify if nozzle is shared or not
            if !sharedNozzle {
                if let tool = temp["tool1"] as? NSDictionary {
                    tool1TempActual = tool["actual"] as? Double
                    tool1TempTarget = tool["target"] as? Double
                }
                if let tool = temp["tool2"] as? NSDictionary {
                    tool2TempActual = tool["actual"] as? Double
                    tool2TempTarget = tool["target"] as? Double
                }
                if let tool = temp["tool3"] as? NSDictionary {
                    tool3TempActual = tool["actual"] as? Double
                    tool3TempTarget = tool["target"] as? Double
                }
                if let tool = temp["tool4"] as? NSDictionary {
                    tool4TempActual = tool["actual"] as? Double
                    tool4TempTarget = tool["target"] as? Double
                }
            }
            if let chamber = temp["chamber"] as? NSDictionary {
                chamberTempActual = chamber["actual"] as? Double
                chamberTempTarget = chamber["target"] as? Double
            }
            if let time = temp["time"] as? Int {
                tempTime = time
            }
        }
        
        mutating func parseTemps(event: CurrentStateEvent) {
            bedTempActual = event.bedTempActual
            bedTempTarget = event.bedTempTarget

            tool0TempActual = event.tool0TempActual
            tool0TempTarget = event.tool0TempTarget

            tool1TempActual = event.tool1TempActual
            tool1TempTarget = event.tool1TempTarget
            
            tool2TempActual = event.tool2TempActual
            tool2TempTarget = event.tool2TempTarget
            
            tool3TempActual = event.tool3TempActual
            tool3TempTarget = event.tool3TempTarget
            
            tool4TempActual = event.tool4TempActual
            tool4TempTarget = event.tool4TempTarget
            
            chamberTempActual = event.chamberTempActual
            chamberTempTarget = event.chamberTempTarget

            tempTime = event.tempTime
        }
    }
    
    // Variable can be read but cannot be modified
    public private(set) var temps: Array<Temp> = Array()
    
    func addHistory(history: Array<Temp>) {
        // History is sent when websocket gets initially connected so drop previous history
        temps = Array()
        temps.append(contentsOf: history)

        // Make sure that we do not go over the limit of history we keep in memory
        if history.count > MAX_HISTORY_SIZE {
            let toDeleteCount = history.count - MAX_HISTORY_SIZE
            temps.removeFirst(toDeleteCount)
        }
    }
    
    func addTemp(temp: Temp) {
        // Make sure that we do not go over the limit of history we keep in memory
        if temps.count > MAX_HISTORY_SIZE {
            temps.removeFirst(1)
        }
        temps.append(temp)
    }
    
    func clear() {
        temps = Array()
    }
    
}
