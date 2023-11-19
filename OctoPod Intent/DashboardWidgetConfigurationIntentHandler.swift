import Foundation
import Intents

@available(iOSApplicationExtension 14.0, *)
class DashboardWidgetConfigurationIntentHandler: NSObject, DashboardWidgetConfigurationIntentHandling {
    private let printerManager: PrinterManager
    
    init(printerManager: PrinterManager) {
        self.printerManager = printerManager
    }
    
    // MARK: Possible values

    func providePrinter1OptionsCollection(for intent: DashboardWidgetConfigurationIntent, with completion: @escaping (INObjectCollection<WidgetPrinter>?, Error?) -> Void) {
        providePrinterOptionsCollection(for: intent, with: completion)
    }
    
    func providePrinter2OptionsCollection(for intent: DashboardWidgetConfigurationIntent, with completion: @escaping (INObjectCollection<WidgetPrinter>?, Error?) -> Void) {
        providePrinterOptionsCollection(for: intent, with: completion)
    }
    
    func providePrinter3OptionsCollection(for intent: DashboardWidgetConfigurationIntent, with completion: @escaping (INObjectCollection<WidgetPrinter>?, Error?) -> Void) {
        providePrinterOptionsCollection(for: intent, with: completion)
    }
    
    func providePrinter4OptionsCollection(for intent: DashboardWidgetConfigurationIntent, with completion: @escaping (INObjectCollection<WidgetPrinter>?, Error?) -> Void) {
        providePrinterOptionsCollection(for: intent, with: completion)
    }
    
    
    // MARK: Default values
    
    func defaultPrinter1(for intent: DashboardWidgetConfigurationIntent) -> WidgetPrinter? {
        // If intent has proper values then use it
        if let widgetPrinter = intent.printer1, let _ = widgetPrinter.url {
            return widgetPrinter
        }
        // If not return a new widget printer based on the default printer
        return defaultPrinter(index: 0)
    }

    func defaultPrinter2(for intent: DashboardWidgetConfigurationIntent) -> WidgetPrinter? {
        // If intent has proper values then use it
        if let widgetPrinter = intent.printer2, let _ = widgetPrinter.url {
            return widgetPrinter
        }
        // If not return a new widget printer based on the default printer
        return defaultPrinter(index: 1)
    }

    func defaultPrinter3(for intent: DashboardWidgetConfigurationIntent) -> WidgetPrinter? {
        // If intent has proper values then use it
        if let widgetPrinter = intent.printer3, let _ = widgetPrinter.url {
            return widgetPrinter
        }
        // If not return a new widget printer based on the default printer
        return defaultPrinter(index: 2)
    }

    func defaultPrinter4(for intent: DashboardWidgetConfigurationIntent) -> WidgetPrinter? {
        // If intent has proper values then use it
        if let widgetPrinter = intent.printer4, let _ = widgetPrinter.url {
            return widgetPrinter
        }
        // If not return a new widget printer based on the default printer
        return defaultPrinter(index: 3)
    }

    // MARK: - Private functions

    fileprivate func createWidgetPrinter(printer: Printer) -> WidgetPrinter {
        let widgetPrinter = WidgetPrinter(identifier: printer.name, display: printer.name)
        widgetPrinter.name = printer.name
        widgetPrinter.url = printer.objectID.uriRepresentation().absoluteString
        widgetPrinter.hostname = printer.hostname
        widgetPrinter.apiKey = printer.apiKey
        widgetPrinter.username = printer.username
        widgetPrinter.password = printer.password
        widgetPrinter.preemptiveAuth = printer.preemptiveAuthentication() ? 1 : 0
        
        return widgetPrinter
    }
    
    fileprivate func providePrinterOptionsCollection(for intent: DashboardWidgetConfigurationIntent, with completion: @escaping (INObjectCollection<WidgetPrinter>?, Error?) -> Void) {
        var widgetPrinters: [WidgetPrinter] = []
        printerManager.getPrinters(context: printerManager.safePrivateContext()) { (printers: [Printer]) in
            for printer in printers {
                widgetPrinters.append(createWidgetPrinter(printer: printer))
            }
        }
        // Create a collection with the array of characters.
        let collection = INObjectCollection(items: widgetPrinters)

        // Call the completion handler, passing the collection.
        completion(collection, nil)
    }

    fileprivate func defaultPrinter(index: Int) -> WidgetPrinter? {
        var widgetPrinter: WidgetPrinter?
        printerManager.getPrinters(context: printerManager.safePrivateContext()) { (printers: [Printer]) in
            if printers.count > index {
                widgetPrinter = createWidgetPrinter(printer: printers[index])
            }
        }
        return widgetPrinter
    }
}
