import Foundation

class PaletteConnectIntentHandler: NSObject, PaletteConnectIntentHandling {
 
    private let printerManager: PrinterManager
    
    init(printerManager: PrinterManager) {
        self.printerManager = printerManager
    }
    
    func handle(intent: PaletteConnectIntent, completion: @escaping (PaletteConnectIntentResponse) -> Void) {
        if let printerURL = intent.printerURL, let url = URL(string: printerURL), let printer = printerManager.getPrinterByObjectURL(url: url) {
            let intentsController = IntentsController()
            intentsController.palette2Connect(printer: printer) { (requested: Bool) in
                let response = PaletteConnectIntentResponse(code: requested ? .success : .failure, userActivity: nil)
                completion(response)
            }
        } else {
            let response = PaletteConnectIntentResponse(code: .failure, userActivity: nil)
            completion(response)
        }
    }
}
