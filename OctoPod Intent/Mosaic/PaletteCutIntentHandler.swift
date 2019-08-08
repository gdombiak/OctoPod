import Foundation

class PaletteCutIntentHandler: NSObject, PaletteCutIntentHandling {
    
    private let printerManager: PrinterManager
    
    init(printerManager: PrinterManager) {
        self.printerManager = printerManager
    }
    
    func handle(intent: PaletteCutIntent, completion: @escaping (PaletteCutIntentResponse) -> Void) {
        if let printerURL = intent.printerURL, let url = URL(string: printerURL), let printer = printerManager.getPrinterByObjectURL(url: url) {
            let intentsController = IntentsController()
            intentsController.palette2Cut(printer: printer) { (requested: Bool) in
                let response = PaletteCutIntentResponse(code: requested ? .success : .failure, userActivity: nil)
                completion(response)
            }
        } else {
            let response = PaletteCutIntentResponse(code: .failure, userActivity: nil)
            completion(response)
        }
    }
}
