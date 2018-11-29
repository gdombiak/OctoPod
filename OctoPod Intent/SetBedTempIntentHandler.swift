import Foundation

class SetBedTempIntentHandler: NSObject, SetBedTempIntentHandling {

    func handle(intent: SetBedTempIntent, completion: @escaping (SetBedTempIntentResponse) -> Void) {
        let intentsController = IntentsController()        
        intentsController.bedTemperature(intent: intent) { (requested: Bool, newTarget: Int?, httpStatusCode: Int) in
            let response = SetBedTempIntentResponse(code: requested ? .success : .failure, userActivity: nil)
            if let targetTemp = newTarget {
                response.temperature = targetTemp as NSNumber
            }
            response.statusCode = httpStatusCode as NSNumber
            completion(response)
        }
    }
}
