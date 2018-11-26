import Foundation

class RestartJobIntentHandler: NSObject, RestartJobIntentHandling {
    
    func handle(intent: RestartJobIntent, completion: @escaping (RestartJobIntentResponse) -> Void) {
        let intentsController = IntentsController()
        intentsController.restartJob(intent: intent) { (requested: Bool) in
            let response = RestartJobIntentResponse(code: requested ? .success : .failure, userActivity: nil)
            completion(response)
        }
    }
}

