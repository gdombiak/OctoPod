import Foundation
import Intents

@available(iOSApplicationExtension 14.0, *)
class WidgetConfigurationIntentHandler: NSObject, WidgetConfigurationIntentHandling {

    private let printerManager: PrinterManager
    
    init(printerManager: PrinterManager) {
        self.printerManager = printerManager
    }
    
    func resolvePrinter(for intent: WidgetConfigurationIntent, with completion: @escaping (WidgetPrinterResolutionResult) -> Void) {
        if let printerURL = intent.printer?.url, let url = URL(string: printerURL), let latestPrinter = printerManager.getPrinterByObjectURL(url: url) {
            let updatedConfigurationIntent = createWidgetPrinter(printer: latestPrinter)
            completion(WidgetPrinterResolutionResult.success(with: updatedConfigurationIntent))
        } else {
            // This case should not happen. Just in case offer default printer as a fallback
            if let printer = printerManager.getDefaultPrinter() {
                let widgetPrinter = createWidgetPrinter(printer: printer)

                let response = WidgetPrinterResolutionResult.disambiguation(with: [widgetPrinter])
                completion(response)
            } else {
                // This case has even less chances of happening
                fatalError("Widget selected invalid printer and OctoPod has no printers defined")
            }
        }
    }
    
    func providePrinterOptionsCollection(for intent: WidgetConfigurationIntent, with completion: @escaping (INObjectCollection<WidgetPrinter>?, Error?) -> Void) {
        let widgetPrinters: [WidgetPrinter] = printerManager.getPrinters().map { printer in
            return createWidgetPrinter(printer: printer)
        }
        // Create a collection with the array of characters.
        let collection = INObjectCollection(items: widgetPrinters)

        // Call the completion handler, passing the collection.
        completion(collection, nil)
    }
    
    func defaultPrinter(for intent: WidgetConfigurationIntent) -> WidgetPrinter? {
        // If intent has proper values then use it
        if let widgetPrinter = intent.printer, let _ = widgetPrinter.url {
            return widgetPrinter
        }
        // If not return a new widget printer based on the default printer
        if let printer = printerManager.getDefaultPrinter() {
            return createWidgetPrinter(printer: printer)
        }
        return nil
    }
    
    // MARK: - Private functions

    private func createWidgetPrinter(printer: Printer) -> WidgetPrinter {
        let widgetPrinter = WidgetPrinter(identifier: printer.name, display: printer.name)
        widgetPrinter.name = printer.name
        widgetPrinter.url = printer.objectID.uriRepresentation().absoluteString
        widgetPrinter.hostname = printer.hostname
        widgetPrinter.apiKey = printer.apiKey
        widgetPrinter.username = printer.username
        widgetPrinter.password = printer.password
        
        widgetPrinter.cameraURL = octoPrintCameraAbsoluteUrl(hostname: printer.hostname, streamUrl: printer.getStreamPath())
        widgetPrinter.cameraOrientation = NSNumber(value: Int(printer.cameraOrientation))
        return widgetPrinter
    }
    
    fileprivate func octoPrintCameraAbsoluteUrl(hostname: String, streamUrl: String) -> String {
        if streamUrl.isEmpty {
            // Should never happen but let's be cautious
            return hostname
        }
        if streamUrl.starts(with: "/") {
            // Build absolute URL from relative URL
            return hostname + streamUrl
        }
        // streamURL is an absolute URL so return it
        return streamUrl
    }

}
