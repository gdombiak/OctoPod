import Foundation

class RemainingTimeIntentHandler: NSObject, RemainingTimeIntentHandling {
    
    func handle(intent: RemainingTimeIntent, completion: @escaping (RemainingTimeIntentResponse) -> Void) {
        let intentsController = IntentsController()
        intentsController.remainingTime(intent: intent) { (requested: Bool, time: String?, httpStatusCode: Int) in
            let response = RemainingTimeIntentResponse(code: requested ? .success : .failure, userActivity: nil)
            if let time = time {
                response.time = time
            }
            response.statusCode = httpStatusCode as NSNumber
            completion(response)
        }

    }
}
