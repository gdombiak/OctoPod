import Foundation

class SetBedTempIntentHandler: NSObject, SetBedTempIntentHandling {
    
    private let printerManager: PrinterManager
    
    init(printerManager: PrinterManager) {
        self.printerManager = printerManager
    }

    func handle(intent: SetBedTempIntent, completion: @escaping (SetBedTempIntentResponse) -> Void) {
        if let printerURL = intent.printerURL, let url = URL(string: printerURL), let printer = printerManager.getPrinterByObjectURL(url: url) {
            let intentsController = IntentsController()
            intentsController.bedTemperature(printer: printer, temperature: intent.temperature) { (requested: Bool, newTarget: Int?, httpStatusCode: Int) in
                let response = SetBedTempIntentResponse(code: requested ? .success : .failure, userActivity: nil)
                if let targetTemp = newTarget {
                    response.temperature = targetTemp as NSNumber
                }
                response.statusCode = httpStatusCode as NSNumber
                completion(response)
            }
        } else {
            let response = SetBedTempIntentResponse(code: .failure, userActivity: nil)
            response.statusCode = -1
            completion(response)
        }
    }
}
