import Foundation

class RemainingTimeIntentHandler: NSObject, RemainingTimeIntentHandling {
    
    private let printerManager: PrinterManager
    
    init(printerManager: PrinterManager) {
        self.printerManager = printerManager
    }
    
    func handle(intent: RemainingTimeIntent, completion: @escaping (RemainingTimeIntentResponse) -> Void) {
        if let printerURL = intent.printerURL, let url = URL(string: printerURL), let printer = printerManager.getPrinterByObjectURL(url: url) {
            let intentsController = IntentsController()
            intentsController.remainingTime(printer: printer) { (requested: Bool, time: String?, httpStatusCode: Int) in
                let response = RemainingTimeIntentResponse(code: requested ? .success : .failure, userActivity: nil)
                if let time = time {
                    response.time = time
                }
                response.statusCode = httpStatusCode as NSNumber
                completion(response)
            }
        } else {
            let response = RemainingTimeIntentResponse(code: .failure, userActivity: nil)
            response.statusCode = -1
            completion(response)
        }
    }
}
