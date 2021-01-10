import Foundation

class SoCTempHistory {
    
    private let MAX_HISTORY_SIZE = 400

    struct Temp {
        // Time when temp was measured
        var tempTime: Int?

        // SoC temperature
        var tempActual: Double?
        
        mutating func parseTemps(data: NSDictionary) {
            if let temp = data["temp"] as? Double {
                tempActual = temp
            }
            
            if let time = data["time"] as? Int {
                tempTime = time
            }
        }
    }
    
    // Variable can be read but cannot be modified
    public private(set) var temps: Array<Temp> = Array()
    
    func addHistory(history: Array<Temp>) {
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
