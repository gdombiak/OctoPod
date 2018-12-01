import Foundation

class CoolDownPrinterIntentHandler: NSObject, CoolDownPrinterIntentHandling {
    
    private let printerManager: PrinterManager
    
    init(printerManager: PrinterManager) {
        self.printerManager = printerManager
    }
    
    func handle(intent: CoolDownPrinterIntent, completion: @escaping (CoolDownPrinterIntentResponse) -> Void) {
        if let printerURL = intent.printerURL, let url = URL(string: printerURL), let printer = printerManager.getPrinterByObjectURL(url: url) {
            let intentsController = IntentsController()
            intentsController.coolDownPrinter(printer: printer) { (requested: Bool, httpStatusCode: Int) in
                let response = CoolDownPrinterIntentResponse(code: requested ? .success : .failure, userActivity: nil)
                response.statusCode = httpStatusCode as NSNumber
                completion(response)
            }
        } else {
            let response = CoolDownPrinterIntentResponse(code: .failure, userActivity: nil)
            response.statusCode = -1
            completion(response)
        }
    }
}
