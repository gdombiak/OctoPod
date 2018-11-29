import Foundation

class ResumeJobIntentHandler: NSObject, ResumeJobIntentHandling {
    
    func handle(intent: ResumeJobIntent, completion: @escaping (ResumeJobIntentResponse) -> Void) {
        let intentsController = IntentsController()
        intentsController.resumeJob(intent: intent) { (requested: Bool, httpStatusCode: Int) in
            let response = ResumeJobIntentResponse(code: requested ? .success : .failure, userActivity: nil)
            response.statusCode = httpStatusCode as NSNumber
            completion(response)
        }
    }
}

