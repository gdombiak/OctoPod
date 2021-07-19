import Foundation

class PSUControlOffIntentHandler: NSObject, PSUControlOffIntentHandling {
    private let printerManager: PrinterManager
    
    init(printerManager: PrinterManager) {
        self.printerManager = printerManager
    }

    func handle(intent: PSUControlOffIntent, completion: @escaping (PSUControlOffIntentResponse) -> Void) {
        if let printerURL = intent.printerURL, let url = URL(string: printerURL), let printer = printerManager.getPrinterByObjectURL(url: url) {
            // Turn off PSU Control
            let intentsController = IntentsController()
            intentsController.powerPSUControl(printer: printer, on: false) { (requested: Bool, httpStatusCode: Int) in
                let response = PSUControlOffIntentResponse(code: requested ? .success : .failure, userActivity: nil)
                completion(response)
            }
        } else {
            // Printer no longer valid or some unexpected situation
            // This case should not happen
            completion(PSUControlOffIntentResponse(code: .failure, userActivity: nil))
        }
    }
}
