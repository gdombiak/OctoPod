import Foundation

class PSUControlOnIntentHandler: NSObject, PSUControlOnIntentHandling {
    private let printerManager: PrinterManager
    
    init(printerManager: PrinterManager) {
        self.printerManager = printerManager
    }

    func handle(intent: PSUControlOnIntent, completion: @escaping (PSUControlOnIntentResponse) -> Void) {
        if let printerURL = intent.printerURL, let url = URL(string: printerURL), let printer = printerManager.getPrinterByObjectURL(url: url) {
            // Turn on PSU Control
            let intentsController = IntentsController()
            intentsController.powerPSUControl(printer: printer, on: true) { (requested: Bool, httpStatusCode: Int) in
                let response = PSUControlOnIntentResponse(code: requested ? .success : .failure, userActivity: nil)
                completion(response)
            }
        } else {
            // Printer no longer valid or some unexpected situation
            // This case should not happen
            completion(PSUControlOnIntentResponse(code: .failure, userActivity: nil))
        }
    }
}
