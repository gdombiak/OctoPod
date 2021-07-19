import Foundation

class EnclosureTurnOnIntentHandler: NSObject, EnclosureTurnOnIntentHandling {
    private let printerManager: PrinterManager
    
    init(printerManager: PrinterManager) {
        self.printerManager = printerManager
    }

    func handle(intent: EnclosureTurnOnIntent, completion: @escaping (EnclosureTurnOnIntentResponse) -> Swift.Void) {
        if let printerURL = intent.printerURL, let url = URL(string: printerURL), let printer = printerManager.getPrinterByObjectURL(url: url) {
            // Retrieve the EnclosureOutput
            if let regularOutput = printer.getEnclosureRegularOutputs().first(where: { (anEnclosureOutput) -> Bool in
                return anEnclosureOutput.label == intent.label
            }) {
                // Turn on switch
                let intentsController = IntentsController()
                intentsController.changeEnclosureGPIO(printer: printer, index_id: regularOutput.index_id, status: true) { (requested: Bool, httpStatusCode: Int) in
                    let response = EnclosureTurnOnIntentResponse(code: requested ? .success : .failure, userActivity: nil)
                    completion(response)
                }
            } else {
                // Switch not found
                completion(EnclosureTurnOnIntentResponse(code: .failure, userActivity: nil))
            }
        } else {
            // Printer no longer valid or some unexpected situation
            // This case should not happen
            completion(EnclosureTurnOnIntentResponse(code: .failure, userActivity: nil))
        }
    }
}
