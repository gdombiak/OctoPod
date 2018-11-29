import Foundation

class RestartJobIntentHandler: NSObject, RestartJobIntentHandling {
    
    func handle(intent: RestartJobIntent, completion: @escaping (RestartJobIntentResponse) -> Void) {
        let intentsController = IntentsController()
        intentsController.restartJob(intent: intent) { (requested: Bool, httpStatusCode: Int) in
            let response = RestartJobIntentResponse(code: requested ? .success : .failure, userActivity: nil)
            response.statusCode = httpStatusCode as NSNumber
            completion(response)
        }
    }
}

