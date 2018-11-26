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
    
    // MARK: - Private functions
    
    fileprivate func getRESTClient(hostname: String, apiKey: String, username: String?, password: String?) -> OctoPrintRESTClient {
        let restClient = OctoPrintRESTClient()
        restClient.connectToServer(serverURL: hostname, apiKey: apiKey, username: username, password: password)
        return restClient
    }
}
