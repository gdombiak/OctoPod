import Foundation

class PaletteClearIntentHandler: NSObject, PaletteClearIntentHandling {
    
    private let printerManager: PrinterManager
    
    init(printerManager: PrinterManager) {
        self.printerManager = printerManager
    }
    
    func handle(intent: PaletteClearIntent, completion: @escaping (PaletteClearIntentResponse) -> Void) {
        if let printerURL = intent.printerURL, let url = URL(string: printerURL), let printer = printerManager.getPrinterByObjectURL(url: url) {
            let intentsController = IntentsController()
            intentsController.palette2Clear(printer: printer) { (requested: Bool) in
                let response = PaletteClearIntentResponse(code: requested ? .success : .failure, userActivity: nil)
                completion(response)
            }
        } else {
            let response = PaletteClearIntentResponse(code: .failure, userActivity: nil)
            completion(response)
        }
    }
}
