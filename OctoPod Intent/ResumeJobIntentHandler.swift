import Foundation

class ResumeJobIntentHandler: NSObject, ResumeJobIntentHandling {
    
    private let printerManager: PrinterManager
    
    init(printerManager: PrinterManager) {
        self.printerManager = printerManager
    }
    
    func handle(intent: ResumeJobIntent, completion: @escaping (ResumeJobIntentResponse) -> Void) {
        if let printerURL = intent.printerURL, let url = URL(string: printerURL), let printer = printerManager.getPrinterByObjectURL(url: url) {
            let intentsController = IntentsController()
            intentsController.resumeJob(printer: printer) { (requested: Bool, httpStatusCode: Int) in
                let response = ResumeJobIntentResponse(code: requested ? .success : .failure, userActivity: nil)
                response.statusCode = httpStatusCode as NSNumber
                completion(response)
            }
        } else {
            let response = ResumeJobIntentResponse(code: .failure, userActivity: nil)
            response.statusCode = -1
            completion(response)
        }
    }
}

