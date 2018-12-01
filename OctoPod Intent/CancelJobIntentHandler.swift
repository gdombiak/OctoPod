import Foundation

class CancelJobIntentHandler: NSObject, CancelJobIntentHandling {
    
    private let printerManager: PrinterManager
    
    init(printerManager: PrinterManager) {
        self.printerManager = printerManager
    }
    
    func handle(intent: CancelJobIntent, completion: @escaping (CancelJobIntentResponse) -> Void) {
        if let printerURL = intent.printerURL, let url = URL(string: printerURL), let printer = printerManager.getPrinterByObjectURL(url: url) {
            let intentsController = IntentsController()
            intentsController.cancelJob(printer: printer) { (requested: Bool, httpStatusCode: Int) in
                let response = CancelJobIntentResponse(code: requested ? .success : .failure, userActivity: nil)
                response.statusCode = httpStatusCode as NSNumber
                completion(response)
            }
        } else {
            let response = CancelJobIntentResponse(code: .failure, userActivity: nil)
            response.statusCode = -1
            completion(response)
        }
    }
}

