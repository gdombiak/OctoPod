import Foundation

class PauseJobIntentHandler: NSObject, PauseJobIntentHandling {
    
    private let printerManager: PrinterManager
    
    init(printerManager: PrinterManager) {
        self.printerManager = printerManager
    }
    
    func handle(intent: PauseJobIntent, completion: @escaping (PauseJobIntentResponse) -> Void) {
        if let printerURL = intent.printerURL, let url = URL(string: printerURL), let printer = printerManager.getPrinterByObjectURL(url: url) {
            let intentsController = IntentsController()
            intentsController.pauseJob(printer: printer) { (requested: Bool, httpStatusCode: Int) in
                let response = PauseJobIntentResponse(code: requested ? .success : .failure, userActivity: nil)
                response.statusCode = httpStatusCode as NSNumber
                completion(response)
            }
        } else {
            let response = PauseJobIntentResponse(code: .failure, userActivity: nil)
            response.statusCode = -1
            completion(response)
        }
    }
}
