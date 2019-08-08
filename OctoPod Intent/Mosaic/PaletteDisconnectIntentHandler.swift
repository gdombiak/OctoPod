import Foundation

class PaletteDisconnectIntentHandler: NSObject, PaletteDisconnectIntentHandling {
    
    private let printerManager: PrinterManager
    
    init(printerManager: PrinterManager) {
        self.printerManager = printerManager
    }
    
    func handle(intent: PaletteDisconnectIntent, completion: @escaping (PaletteDisconnectIntentResponse) -> Void) {
        if let printerURL = intent.printerURL, let url = URL(string: printerURL), let printer = printerManager.getPrinterByObjectURL(url: url) {
            let intentsController = IntentsController()
            intentsController.palette2Disconnect(printer: printer) { (requested: Bool) in
                let response = PaletteDisconnectIntentResponse(code: requested ? .success : .failure, userActivity: nil)
                completion(response)
            }
        } else {
            let response = PaletteDisconnectIntentResponse(code: .failure, userActivity: nil)
            completion(response)
        }
    }
}
