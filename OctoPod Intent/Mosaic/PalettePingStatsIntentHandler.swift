import Foundation

class PalettePingStatsIntentHandler: NSObject, PalettePingStatsIntentHandling {
    
    private let printerManager: PrinterManager
    
    init(printerManager: PrinterManager) {
        self.printerManager = printerManager
    }
    
    func handle(intent: PalettePingStatsIntent, completion: @escaping (PalettePingStatsIntentResponse) -> Void) {
        if let printerURL = intent.printerURL, let url = URL(string: printerURL), let printer = printerManager.getPrinterByObjectURL(url: url) {
            let intentsController = IntentsController()
            intentsController.palette2PingStats(printer: printer) { (requested: Bool, lastVariation: String?, maxVariation: String?) in
                let response: PalettePingStatsIntentResponse!
                if requested {
                    if let maxVariation = maxVariation, let lastVariation = lastVariation {
                        response = PalettePingStatsIntentResponse.success(lastVariation: lastVariation, maxVariation: maxVariation)
                    } else {
                        response = PalettePingStatsIntentResponse(code: .unknown, userActivity: nil)
                    }
                } else {
                    response = PalettePingStatsIntentResponse(code: .failure, userActivity: nil)
                }
                completion(response)
            }
        } else {
            let response = PalettePingStatsIntentResponse(code: .failure, userActivity: nil)
            completion(response)
        }
    }
}
