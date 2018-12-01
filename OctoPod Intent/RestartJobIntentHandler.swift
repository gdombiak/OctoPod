import Foundation

class RestartJobIntentHandler: NSObject, RestartJobIntentHandling {
    
    private let printerManager: PrinterManager
    
    init(printerManager: PrinterManager) {
        self.printerManager = printerManager
    }
    
    func handle(intent: RestartJobIntent, completion: @escaping (RestartJobIntentResponse) -> Void) {
        if let printerURL = intent.printerURL, let url = URL(string: printerURL), let printer = printerManager.getPrinterByObjectURL(url: url) {
            let intentsController = IntentsController()
            intentsController.restartJob(printer: printer) { (requested: Bool, httpStatusCode: Int) in
                let response = RestartJobIntentResponse(code: requested ? .success : .failure, userActivity: nil)
                response.statusCode = httpStatusCode as NSNumber
                completion(response)
            }
        } else {
            let response = RestartJobIntentResponse(code: .failure, userActivity: nil)
            response.statusCode = -1
            completion(response)
        }
    }
}

