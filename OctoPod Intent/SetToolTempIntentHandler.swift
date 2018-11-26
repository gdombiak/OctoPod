import Foundation

class SetToolTempIntentHandler: NSObject, SetToolTempIntentHandling {
    
    func handle(intent: SetToolTempIntent, completion: @escaping (SetToolTempIntentResponse) -> Void) {
        let intentsController = IntentsController()
        intentsController.toolTemperature(intent: intent) { (requested: Bool, newTarget: Int?) in
            let response = SetToolTempIntentResponse(code: requested ? .success : .failure, userActivity: nil)
            if let targetTemp = newTarget {
                response.temperature = targetTemp as NSNumber
            }
            completion(response)
        }
    }
}
