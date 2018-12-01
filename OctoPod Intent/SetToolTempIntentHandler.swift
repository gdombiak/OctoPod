import Foundation

class SetToolTempIntentHandler: NSObject, SetToolTempIntentHandling {
    
    private let printerManager: PrinterManager
    
    init(printerManager: PrinterManager) {
        self.printerManager = printerManager
    }
    
    func handle(intent: SetToolTempIntent, completion: @escaping (SetToolTempIntentResponse) -> Void) {
        if let printerURL = intent.printerURL, let url = URL(string: printerURL), let printer = printerManager.getPrinterByObjectURL(url: url) {
            let intentsController = IntentsController()
            intentsController.toolTemperature(printer: printer, tool: intent.tool, temperature: intent.temperature) { (requested: Bool, newTarget: Int?, httpStatusCode: Int) in
                let response = SetToolTempIntentResponse(code: requested ? .success : .failure, userActivity: nil)
                if let targetTemp = newTarget {
                    response.temperature = targetTemp as NSNumber
                }
                response.statusCode = httpStatusCode as NSNumber
                completion(response)
            }
        } else {
            let response = SetToolTempIntentResponse(code: .failure, userActivity: nil)
            response.statusCode = -1
            completion(response)
        }
    }
}
