import Foundation

/// Event fired when printer state has changed. When using websockets, this information is being pushed to this client.
/// If websockets is not available then this event is fired with a polling mechanism (future idea)
class CurrentStateEvent {
    
    /// Time when temps were measured
    var tempTime: Int?
    
    /// Bed temperatures
    var bedTempActual: Double?
    var bedTempTarget: Double?
    
    /// Extruder 0 temperatures
    var tool0TempActual: Double?
    var tool0TempTarget: Double?

    /// Extruder 1 temperatures (if present)
    var tool1TempActual: Double?
    var tool1TempTarget: Double?
    
    /// Extruder 2 temperatures (if present)
    var tool2TempActual: Double?
    var tool2TempTarget: Double?
    
    /// Extruder 4 temperatures (if present)
    var tool3TempActual: Double?
    var tool3TempTarget: Double?
    
    /// Extruder 4 temperatures (if present)
    var tool4TempActual: Double?
    var tool4TempTarget: Double?
    
    /// Chamber temperatures (if present)
    var chamberTempActual: Double?
    var chamberTempTarget: Double?
    
    /// Operational, Connecting, Printing from SD, etc.
    var state: String?
    var operational: Bool?
    var closedOrError: Bool?
    var printing: Bool?  // This could represent that printer is printing or printer is uploading file to SD Card. IOW, this means if printer is busy
    var paused: Bool?
    
    /// Current Z position (if present)
    var currentZ: Double?
    
    var progressCompletion: Double?
    var progressPrintTime: Int?
    var progressPrintTimeLeft: Int?
    
    var logs: Array<String>?
    
    // MARK: - Parse operations

    /// Parse temps from received JSON.
    /// Websockets and HTTP use similar format so we can parse with same code
    /// - Parameter temp: JSON of the temp element
    func parseTemps(temp: NSDictionary) {
        if let bed = temp["bed"] as? NSDictionary {
            bedTempActual = bed["actual"] as? Double
            bedTempTarget = bed["target"] as? Double
        }
        if let tool = temp["tool0"] as? NSDictionary {
            tool0TempActual = tool["actual"] as? Double
            tool0TempTarget = tool["target"] as? Double
        }
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
        if let chamber = temp["chamber"] as? NSDictionary {
            chamberTempActual = chamber["actual"] as? Double
            chamberTempTarget = chamber["target"] as? Double
        }
        if let time = temp["time"] as? Int {
            tempTime = time
        }
    }

    /// Parse state from received JSON.
    /// Websockets and HTTP use similar format so we can parse with same code
    /// - Parameter state: JSON of the printer state element
    func parseState(state: NSDictionary) {
        self.state = state["text"] as? String
        if let flags = state["flags"] as? NSDictionary {
            operational  = flags["operational"] as? Bool
            paused = flags["paused"] as? Bool
            printing = flags["printing"] as? Bool
            closedOrError = flags["closedOrError"] as? Bool
        }
    }

    /// Parse progress from received JSON.
    /// - Parameter progress: JSON of the progress element
    func parseProgress(progress: NSDictionary) {
        progressCompletion = progress["completion"] as? Double
        progressPrintTime = progress["printTime"] as? Int
        progressPrintTimeLeft = progress["printTimeLeft"] as? Int
    }
    
    /// Parse received logs (coming from Serial port)
    func parseLogs(logs: NSArray) {
        var newLogs = Array<String>()
        for log in logs {
            newLogs.append(log as! String)
        }
        self.logs = newLogs
    }
}
