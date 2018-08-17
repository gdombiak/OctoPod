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

        mutating func parseTemps(temp: NSDictionary) {
            if let bed = temp["bed"] as? NSDictionary {
                bedTempActual = bed["actual"] as? Double
                bedTempTarget = bed["target"] as? Double
            }
            if let tool0 = temp["tool0"] as? NSDictionary {
                tool0TempActual = tool0["actual"] as? Double
                tool0TempTarget = tool0["target"] as? Double
            }
            if let tool1 = temp["tool1"] as? NSDictionary {
                tool1TempActual = tool1["actual"] as? Double
                tool1TempTarget = tool1["target"] as? Double
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
