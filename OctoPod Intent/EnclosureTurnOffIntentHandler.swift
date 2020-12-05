import Foundation

class EnclosureTurnOffIntentHandler: NSObject, EnclosureTurnOffIntentHandling {
    private let printerManager: PrinterManager
    
    init(printerManager: PrinterManager) {
        self.printerManager = printerManager
    }

    func handle(intent: EnclosureTurnOffIntent, completion: @escaping (EnclosureTurnOffIntentResponse) -> Swift.Void) {
        if let printerURL = intent.printerURL, let url = URL(string: printerURL), let printer = printerManager.getPrinterByObjectURL(url: url) {
            // Retrieve the EnclosureOutput
            if let regularOutput = printer.getEnclosureRegularOutputs().first(where: { (anEnclosureOutput) -> Bool in
                return anEnclosureOutput.label == intent.label
            }) {
                // Turn on switch
                let intentsController = IntentsController()
                intentsController.changeEnclosureGPIO(printer: printer, index_id: regularOutput.index_id, status: false) { (requested: Bool, httpStatusCode: Int) in
                    let response = EnclosureTurnOffIntentResponse(code: requested ? .success : .failure, userActivity: nil)
                    completion(response)
                }
            } else {
                // Switch not found
                completion(EnclosureTurnOffIntentResponse(code: .failure, userActivity: nil))
            }
        } else {
            // Printer no longer valid or some unexpected situation
            // This case should not happen
            completion(EnclosureTurnOffIntentResponse(code: .failure, userActivity: nil))
        }
    }
}
