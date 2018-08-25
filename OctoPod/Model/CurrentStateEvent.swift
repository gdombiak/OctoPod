import Foundation

// Event fired when printer state has changed. When using websockets, this information is being pushed to this client.
// If websockets is not available then this event is fired with a polling mechanism (future idea)
class CurrentStateEvent {
    
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
    
    // Operational, Connecting, Printing from SD, etc.
    var state: String?
    var operational: Bool?
    var closedOrError: Bool?
    var printing: Bool?  // This could represent that printer is printing or printer is uploading file to SD Card. IOW, this means if printer is busy
    var paused: Bool?
    
    // Current Z position (if present)
    var currentZ: Double?
    
    var progressCompletion: Double?
    var progressPrintTime: Int?
    var progressPrintTimeLeft: Int?
    
    var logs: Array<String>?
    
    // MARK: - Parse operations

    // Parse temps from received JSON.
    // Websockets and HTTP use similar format so we can parse with same code
    func parseTemps(temp: NSDictionary) {
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

    // Parse state from received JSON.
    // Websockets and HTTP use similar format so we can parse with same code
    func parseState(state: NSDictionary) {
        self.state = state["text"] as? String
        if let flags = state["flags"] as? NSDictionary {
            operational  = flags["operational"] as? Bool
            paused = flags["paused"] as? Bool
            printing = flags["printing"] as? Bool
            closedOrError = flags["closedOrError"] as? Bool
        }
    }

    // Parse progress from received JSON.
    func parseProgress(progress: NSDictionary) {
        progressCompletion = progress["completion"] as? Double
        progressPrintTime = progress["printTime"] as? Int
        progressPrintTimeLeft = progress["printTimeLeft"] as? Int
    }
    
    // Parse received logs (coming from Serial port)
    func parseLogs(logs: NSArray) {
        var newLogs = Array<String>()
        for log in logs {
            newLogs.append(log as! String)
        }
        self.logs = newLogs
    }
}
