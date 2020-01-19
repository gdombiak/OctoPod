import Foundation
import UIKit

class IntentsController {
    
    // MARK: - Printer intents

    func bedTemperature(printer: Printer, temperature: NSNumber?, callback: @escaping (Bool, Int?, Int) -> Void) {
        let restClient = getRESTClient(hostname: printer.hostname, apiKey: printer.apiKey, username: printer.username, password: printer.password)
        var newTarget: Int = 0
        if let temperature = temperature {
            let tempInt = Int(truncating: temperature)
            newTarget = tempInt <= 0 ? 0 : tempInt
        }
        restClient.bedTargetTemperature(newTarget: newTarget) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
            callback(requested, newTarget, response.statusCode)
        }
    }
    
    func toolTemperature(printer: Printer, tool: NSNumber?, temperature: NSNumber?, callback: @escaping (Bool, Int?, Int) -> Void) {
        let restClient = getRESTClient(hostname: printer.hostname, apiKey: printer.apiKey, username: printer.username, password: printer.password)
        var toolNumber = 0
        if let tool = tool {
            toolNumber = Int(truncating: tool)
        }
        var newTarget: Int = 0
        if let temperature = temperature {
            let tempInt = Int(truncating: temperature)
            newTarget = tempInt <= 0 ? 0 : tempInt
        }
        restClient.toolTargetTemperature(toolNumber: toolNumber, newTarget: newTarget) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
            callback(requested, newTarget, response.statusCode)
        }
    }
    
    func chamberTemperature(printer: Printer, temperature: NSNumber?, callback: @escaping (Bool, Int?, Int) -> Void) {
        let restClient = getRESTClient(hostname: printer.hostname, apiKey: printer.apiKey, username: printer.username, password: printer.password)
        var newTarget: Int = 0
        if let temperature = temperature {
            let tempInt = Int(truncating: temperature)
            newTarget = tempInt <= 0 ? 0 : tempInt
        }
        restClient.chamberTargetTemperature(newTarget: newTarget) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
            callback(requested, newTarget, response.statusCode)
        }
    }
    
    func coolDownPrinter(printer: Printer, callback: @escaping (Bool, Int) -> Void) {
        let restClient = getRESTClient(hostname: printer.hostname, apiKey: printer.apiKey, username: printer.username, password: printer.password)
        // Cool down extruder 0
        restClient.toolTargetTemperature(toolNumber: 0, newTarget: 0) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
            if requested {
                // Request worked so now request to cool down bed
                restClient.bedTargetTemperature(newTarget: 0, callback: { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                    callback(requested, response.statusCode)
                })
            } else {
                callback(requested, response.statusCode)
            }
        }
    }
    
    func pauseJob(printer: Printer, callback: @escaping (Bool, Int) -> Void) {
        let restClient = getRESTClient(hostname: printer.hostname, apiKey: printer.apiKey, username: printer.username, password: printer.password)
        restClient.pauseCurrentJob { (requested: Bool, error: Error?, response: HTTPURLResponse) in
            callback(requested, response.statusCode)
        }
    }
    
    func resumeJob(printer: Printer, callback: @escaping (Bool, Int) -> Void) {
        let restClient = getRESTClient(hostname: printer.hostname, apiKey: printer.apiKey, username: printer.username, password: printer.password)
        restClient.resumeCurrentJob { (requested: Bool, error: Error?, response: HTTPURLResponse) in
            callback(requested, response.statusCode)
        }
    }
    
    func cancelJob(printer: Printer, callback: @escaping (Bool, Int) -> Void) {
        let restClient = getRESTClient(hostname: printer.hostname, apiKey: printer.apiKey, username: printer.username, password: printer.password)
        restClient.cancelCurrentJob { (requested: Bool, error: Error?, response: HTTPURLResponse) in
            callback(requested, response.statusCode)
        }
    }
    
    func restartJob(printer: Printer, callback: @escaping (Bool, Int) -> Void) {
        let restClient = getRESTClient(hostname: printer.hostname, apiKey: printer.apiKey, username: printer.username, password: printer.password)
        restClient.restartCurrentJob { (requested: Bool, error: Error?, response: HTTPURLResponse) in
            callback(requested, response.statusCode)
        }
    }
    
    func remainingTime(printer: Printer, callback: @escaping (Bool, String?, Int) -> Void) {
        let restClient = getRESTClient(hostname: printer.hostname, apiKey: printer.apiKey, username: printer.username, password: printer.password)
        restClient.currentJobInfo { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
            if let result = result as? Dictionary<String, Any>, let progress = result["progress"] as? Dictionary<String, Any> {
                if let printTimeLeft = progress["printTimeLeft"] as? Int {
                    callback(true, self.secondsToTimeLeft(seconds: printTimeLeft), response.statusCode)
                } else if let _ = progress["printTime"] as? Int {
                    callback(true, NSLocalizedString("Unknown", comment: "ETA is Unknown"), response.statusCode)
                } else {
                    callback(true, "0", response.statusCode)
                }
            } else {
                callback(false, nil, response.statusCode)
            }
        }
    }
    
    // MARK: - Palette intents

    func palette2Connect(printer: Printer, callback: @escaping (Bool) -> Void) {
        let restClient = getRESTClient(hostname: printer.hostname, apiKey: printer.apiKey, username: printer.username, password: printer.password)
        restClient.palette2Connect(plugin: Plugins.PALETTE_2, port: "") { (requested: Bool, error: Error?, response: HTTPURLResponse) in
            callback(requested)
        }
    }
    
    func palette2Disconnect(printer: Printer, callback: @escaping (Bool) -> Void) {
        let restClient = getRESTClient(hostname: printer.hostname, apiKey: printer.apiKey, username: printer.username, password: printer.password)
        restClient.palette2Disconnect(plugin: Plugins.PALETTE_2) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
            callback(requested)
        }
    }
    
    func palette2Clear(printer: Printer, callback: @escaping (Bool) -> Void) {
        let restClient = getRESTClient(hostname: printer.hostname, apiKey: printer.apiKey, username: printer.username, password: printer.password)
        restClient.palette2Clear(plugin: Plugins.PALETTE_2) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
            callback(requested)
        }
    }
    
    func palette2Cut(printer: Printer, callback: @escaping (Bool) -> Void) {
        let restClient = getRESTClient(hostname: printer.hostname, apiKey: printer.apiKey, username: printer.username, password: printer.password)
        restClient.palette2Cut(plugin: Plugins.PALETTE_2) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
            callback(requested)
        }
    }
    
    func palette2PingStats(printer: Printer, callback: @escaping (Bool, String?, String?) -> Void) {
        let restClient = getRESTClient(hostname: printer.hostname, apiKey: printer.apiKey, username: printer.username, password: printer.password)
        restClient.palette2PingHistory(plugin: Plugins.PALETTE_2) { (lastVariance: String?, maxVariance: String?, error: Error?, response: HTTPURLResponse) in
            if let lastVariance = lastVariance, let maxVariance = maxVariance {
                callback(true, lastVariance, maxVariance)
            } else if let _ = error, response.statusCode != 200 {
                NSLog("Failed to request ping stats. HTTP status code: \(response.statusCode)")
                callback(false, nil, nil)
            } else {
                // HTTP request was successfully made but there is no enough information
                callback(true, nil, nil)
            }
        }
    }
    
    // MARK: - Private functions
    
    fileprivate func getRESTClient(hostname: String, apiKey: String, username: String?, password: String?) -> OctoPrintRESTClient {
        let restClient = OctoPrintRESTClient()
        restClient.connectToServer(serverURL: hostname, apiKey: apiKey, username: username, password: password)
        return restClient
    }

    fileprivate func secondsToTimeLeft(seconds: Int) -> String {
        if seconds == 0 {
            return "0"
        } else if seconds < 0 {
            // Should never happen but an OctoPrint plugin is returning negative values
            // so return 'Unknown' when this happens
            return NSLocalizedString("Unknown", comment: "ETA is Unknown")
        }
        let duration = TimeInterval(seconds)
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .brief
        formatter.includesApproximationPhrase = true
        formatter.allowedUnits = [ .day, .hour, .minute ]
        return formatter.string(from: duration)!
    }
}
