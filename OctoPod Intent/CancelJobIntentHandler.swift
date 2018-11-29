import Foundation

class CancelJobIntentHandler: NSObject, CancelJobIntentHandling {
    
    func handle(intent: CancelJobIntent, completion: @escaping (CancelJobIntentResponse) -> Void) {
        let intentsController = IntentsController()
        intentsController.cancelJob(intent: intent) { (requested: Bool, httpStatusCode: Int) in
            let response = CancelJobIntentResponse(code: requested ? .success : .failure, userActivity: nil)
            response.statusCode = httpStatusCode as NSNumber
            completion(response)
        }
    }
}

