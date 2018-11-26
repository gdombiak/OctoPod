import Foundation
import UIKit

class IntentsController {
    
    @available(iOS 12.0, *)
    func bedTemperature(intent: SetBedTempIntent, callback: @escaping (Bool, Int?) -> Void) {
        if let hostname = intent.hostname, let apiKey = intent.apiKey {
            let restClient = getRESTClient(hostname: hostname, apiKey: apiKey, username: intent.username, password: intent.password)
            var newTarget: Int = 0
            if let temperature = intent.temperature {
                let tempInt = Int(truncating: temperature)
                newTarget = tempInt <= 0 ? 0 : tempInt
            }
            restClient.bedTargetTemperature(newTarget: newTarget) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                callback(requested, newTarget)
            }
        } else {
            callback(false, nil)
        }
    }
    
    @available(iOS 12.0, *)
    func toolTemperature(intent: SetToolTempIntent, callback: @escaping (Bool, Int?) -> Void) {
        if let hostname = intent.hostname, let apiKey = intent.apiKey {
            let restClient = getRESTClient(hostname: hostname, apiKey: apiKey, username: intent.username, password: intent.password)
            var toolNumber = 0
            if let tool = intent.tool {
                toolNumber = Int(truncating: tool)
            }
            var newTarget: Int = 0
            if let temperature = intent.temperature {
                let tempInt = Int(truncating: temperature)
                newTarget = tempInt <= 0 ? 0 : tempInt
            }
            restClient.toolTargetTemperature(toolNumber: toolNumber, newTarget: newTarget) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                callback(requested, newTarget)
            }
        } else {
            callback(false, nil)
        }
    }
    
    @available(iOS 12.0, *)
    func pauseJob(intent: PauseJobIntent, callback: @escaping (Bool) -> Void) {
        if let hostname = intent.hostname, let apiKey = intent.apiKey {
            let restClient = getRESTClient(hostname: hostname, apiKey: apiKey, username: intent.username, password: intent.password)
            restClient.pauseCurrentJob { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                callback(requested)
            }
        } else {
            callback(false)
        }
    }
    
    @available(iOS 12.0, *)
    func resumeJob(intent: ResumeJobIntent, callback: @escaping (Bool) -> Void) {
        if let hostname = intent.hostname, let apiKey = intent.apiKey {
            let restClient = getRESTClient(hostname: hostname, apiKey: apiKey, username: intent.username, password: intent.password)
            restClient.resumeCurrentJob { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                callback(requested)
            }
        } else {
            callback(false)
        }
    }
    
    @available(iOS 12.0, *)
    func cancelJob(intent: CancelJobIntent, callback: @escaping (Bool) -> Void) {
        if let hostname = intent.hostname, let apiKey = intent.apiKey {
            let restClient = getRESTClient(hostname: hostname, apiKey: apiKey, username: intent.username, password: intent.password)
            restClient.cancelCurrentJob { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                callback(requested)
            }
        } else {
            callback(false)
        }
    }
    
    @available(iOS 12.0, *)
    func restartJob(intent: RestartJobIntent, callback: @escaping (Bool) -> Void) {
        if let hostname = intent.hostname, let apiKey = intent.apiKey {
            let restClient = getRESTClient(hostname: hostname, apiKey: apiKey, username: intent.username, password: intent.password)
            restClient.restartCurrentJob { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                callback(requested)
            }
        } else {
            callback(false)
        }
    }
    
    @available(iOS 12.0, *)
    func remainingTime(intent: RemainingTimeIntent, callback: @escaping (Bool, String?) -> Void) {
        if let hostname = intent.hostname, let apiKey = intent.apiKey {
            let restClient = getRESTClient(hostname: hostname, apiKey: apiKey, username: intent.username, password: intent.password)
            restClient.currentJobInfo { (result: NSObject?, error: Error?, response :HTTPURLResponse) in
                if let result = result as? Dictionary<String, Any>, let progress = result["progress"] as? Dictionary<String, Any> {
                    if let printTimeLeft = progress["printTimeLeft"] as? Int {
                        callback(true, self.secondsToTimeLeft(seconds: printTimeLeft))
                    } else {
                        callback(true, "0")
                    }
                } else {
                    callback(false, nil)
                }
            }
        } else {
            callback(false, nil)
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
            return ""
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
