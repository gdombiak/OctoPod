import Foundation

class PauseJobIntentHandler: NSObject, PauseJobIntentHandling {
    
    func handle(intent: PauseJobIntent, completion: @escaping (PauseJobIntentResponse) -> Void) {
        let intentsController = IntentsController()
        intentsController.pauseJob(intent: intent) { (requested: Bool) in
            let response = PauseJobIntentResponse(code: requested ? .success : .failure, userActivity: nil)
            completion(response)
        }
    }
}
