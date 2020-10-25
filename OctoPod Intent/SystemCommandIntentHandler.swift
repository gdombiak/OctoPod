import Foundation

class SystemCommandIntentHandler: NSObject, SystemCommandIntentHandling {

    private let printerManager: PrinterManager
    
    init(printerManager: PrinterManager) {
        self.printerManager = printerManager
    }

    func handle(intent: SystemCommandIntent, completion: @escaping (SystemCommandIntentResponse) -> Void) {
        if let printerURL = intent.printerURL, let url = URL(string: printerURL), let printer = printerManager.getPrinterByObjectURL(url: url), let action = intent.commandAction, let source = intent.commandSource {
            let intentsController = IntentsController()
            intentsController.systemCommand(printer: printer, action: action, source: source) { (requested: Bool, httpStatusCode: Int) in
                let response = SystemCommandIntentResponse(code: requested ? .success : .failure, userActivity: nil)
                completion(response)
            }
        } else {
            let response = SystemCommandIntentResponse(code: .failure, userActivity: nil)
            completion(response)
        }

    }
}
