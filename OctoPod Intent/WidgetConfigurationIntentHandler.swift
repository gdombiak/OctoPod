import Foundation
import Intents

@available(iOSApplicationExtension 14.0, *)
class WidgetConfigurationIntentHandler: NSObject, WidgetConfigurationIntentHandling {

    private let printerManager: PrinterManager
    
    init(printerManager: PrinterManager) {
        self.printerManager = printerManager
    }
    
    // MARK: Printer Parameter handling

    func resolvePrinter(for intent: WidgetConfigurationIntent, with completion: @escaping (WidgetPrinterResolutionResult) -> Void) {
        if let printerURL = intent.printer?.url, let url = URL(string: printerURL), let selectedPrinter = printerManager.getPrinterByObjectURL(url: url) {
            let widgetPrinter = createWidgetPrinter(printer: selectedPrinter)
            completion(WidgetPrinterResolutionResult.success(with: widgetPrinter))
        } else {
            // This case should not happen
            completion(WidgetPrinterResolutionResult.needsValue())
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
    
    // MARK: Camera Parameter handling

    func resolveCamera(for intent: WidgetConfigurationIntent, with completion: @escaping (WidgetCameraResolutionResult) -> Void) {
        if let cameraWidget = intent.camera, let _ = cameraWidget.cameraURL {
            completion(WidgetCameraResolutionResult.success(with: cameraWidget))
        } else {
            // This case should not happen
            completion(WidgetCameraResolutionResult.needsValue())
        }
    }
    
    func provideCameraOptionsCollection(for intent: WidgetConfigurationIntent, with completion: @escaping (INObjectCollection<WidgetCamera>?, Error?) -> Void) {
        var widgetCameras: [WidgetCamera] = []
        if let printerURL = intent.printer?.url, let url = URL(string: printerURL), let selectedPrinter = printerManager.getPrinterByObjectURL(url: url) {
            if let cameras = selectedPrinter.getMultiCameras(), !cameras.isEmpty {
                // MultiCam plugin is installed so show all cameras
                for multiCamera in cameras {
                    var cameraURL: String
                    var cameraOrientation: Int
                    let url = multiCamera.cameraURL
                    if url == selectedPrinter.getStreamPath() {
                        // This is camera hosted by OctoPrint so respect orientation
                        cameraURL = CameraUtils.shared.absoluteURL(hostname: selectedPrinter.hostname, streamUrl: url)
                        cameraOrientation = Int(selectedPrinter.cameraOrientation)
                    } else {
                        if url.starts(with: "/") {
                            // Another camera hosted by OctoPrint so build absolute URL
                            cameraURL = CameraUtils.shared.absoluteURL(hostname: selectedPrinter.hostname, streamUrl: url)
                        } else {
                            // Use absolute URL to render camera
                            cameraURL = url
                        }
                        cameraOrientation = Int(multiCamera.cameraOrientation) // Respect orientation defined by MultiCamera plugin
                    }
                    widgetCameras.append(createWidgetCamera(name: multiCamera.name, cameraURL: cameraURL, cameraOrientation: cameraOrientation))
                }
            } else {
                // MultiCam plugin is not installed so just show default camera
                let cameraURL = CameraUtils.shared.absoluteURL(hostname: selectedPrinter.hostname, streamUrl: selectedPrinter.getStreamPath())
                let cameraOrientation = Int(selectedPrinter.cameraOrientation)
                widgetCameras.append(createWidgetCamera(name: NSLocalizedString("Default", comment: ""), cameraURL: cameraURL, cameraOrientation: cameraOrientation))
            }
        }
        
        // Create a collection with the array of characters.
        let collection = INObjectCollection(items: widgetCameras)

        // Call the completion handler, passing the collection.
        completion(collection, nil)
    }
    
    // MARK: Default values
    
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
    
//    func defaultCamera(for intent: WidgetConfigurationIntent) -> WidgetCamera? {
//        // If intent has proper values then use it
//        if let widgetCamera = intent.camera, let _ = widgetCamera.cameraURL {
//            return widgetCamera
//        }
//        // Use printer of intent if any, if not use default printer
//        var printer: Printer?
//        if let printerURL = intent.printer?.url, let url = URL(string: printerURL), let selectedPrinter = printerManager.getPrinterByObjectURL(url: url) {
//            printer = selectedPrinter
//        } else if let defaultPrinter = printerManager.getDefaultPrinter() {
//            printer = defaultPrinter
//        }
//
//        // If a printer was found then return camera of printer
//        if let printer = printer {
//            if let cameras = printer.getMultiCameras(), !cameras.isEmpty {
//                // MultiCam plugin is installed so return first camera from list
//                let multiCamera = cameras[0]
//                var cameraURL: String
//                var cameraOrientation: Int
//                let url = multiCamera.cameraURL
//                if url == printer.getStreamPath() {
//                    // This is camera hosted by OctoPrint so respect orientation
//                    cameraURL = CameraUtils.shared.absoluteURL(hostname: printer.hostname, streamUrl: url)
//                    cameraOrientation = Int(printer.cameraOrientation)
//                } else {
//                    if url.starts(with: "/") {
//                        // Another camera hosted by OctoPrint so build absolute URL
//                        cameraURL = CameraUtils.shared.absoluteURL(hostname: printer.hostname, streamUrl: url)
//                    } else {
//                        // Use absolute URL to render camera
//                        cameraURL = url
//                    }
//                    cameraOrientation = Int(multiCamera.cameraOrientation) // Respect orientation defined by MultiCamera plugin
//                }
//                return createWidgetCamera(name: multiCamera.name, cameraURL: cameraURL, cameraOrientation: cameraOrientation)
//            } else {
//                // MultiCam plugin is not installed so use default camera
//                let cameraURL = CameraUtils.shared.absoluteURL(hostname: printer.hostname, streamUrl: printer.getStreamPath())
//                let cameraOrientation = Int(printer.cameraOrientation)
//                return createWidgetCamera(name: NSLocalizedString("Default", comment: ""), cameraURL: cameraURL, cameraOrientation: cameraOrientation)
//            }
//        }
//        return nil
//    }
    
    // MARK: - Private functions

    private func createWidgetPrinter(printer: Printer) -> WidgetPrinter {
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
    
    private func createWidgetCamera(name: String, cameraURL: String, cameraOrientation: Int) -> WidgetCamera {
        let widgetCamera = WidgetCamera(identifier: name, display: name)
        
        widgetCamera.name = name
        widgetCamera.cameraURL = cameraURL
        widgetCamera.cameraOrientation = NSNumber(value: cameraOrientation)
        return widgetCamera
    }
}
