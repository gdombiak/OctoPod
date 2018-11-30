import Foundation

class CoolDownPrinterIntentHandler: NSObject, CoolDownPrinterIntentHandling {
    
    func handle(intent: CoolDownPrinterIntent, completion: @escaping (CoolDownPrinterIntentResponse) -> Void) {
        let intentsController = IntentsController()
        intentsController.coolDownPrinter(intent: intent) { (requested: Bool, httpStatusCode: Int) in
            let response = CoolDownPrinterIntentResponse(code: requested ? .success : .failure, userActivity: nil)
            response.statusCode = httpStatusCode as NSNumber
            completion(response)
        }
    }
}
