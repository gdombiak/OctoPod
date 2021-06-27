import Foundation
import UIKit
import Intents
import UniformTypeIdentifiers
import MobileCoreServices

class TakeSnapshotIntentHandler: NSObject, TakeSnapshotIntentHandling {
        
    private let printerManager: PrinterManager
    
    init(printerManager: PrinterManager) {
        self.printerManager = printerManager
    }
    
    func handle(intent: TakeSnapshotIntent, completion: @escaping (TakeSnapshotIntentResponse) -> Void) {
        if let printerURL = intent.printerURL, let url = URL(string: printerURL), let printer = printerManager.getPrinterByObjectURL(url: url), #available(iOSApplicationExtension 14.0, *) {
            let url = CameraUtils.shared.absoluteURL(hostname: printer.hostname, streamUrl: printer.getStreamPath())
            let cameraOrientation = UIImage.Orientation(rawValue: Int(printer.cameraOrientation))!
            if let cameraURL = URL(string: url) {
                // Take snapshot of default (first) printer's camera
                CameraUtils.shared.renderImage(cameraURL: cameraURL, imageOrientation: cameraOrientation, username: printer.username, password: printer.password, preemptive: printer.preemptiveAuthentication()) { (image: UIImage?, errorMessage: String?) in
                    if let image = image {
                        let response = TakeSnapshotIntentResponse(code: .success, userActivity: nil)
                        let data = image.pngData()!
                        response.image = INFile(data: data, filename: "snapshot", typeIdentifier: UTType.jpeg.identifier)
                        response.imageAspectRatio16_9 = printer.firstCameraAspectRatio16_9 ? 1 : 0
                        completion(response)
                    } else {
                        // Some error happened
                        if let errorMessage = errorMessage {
                            NSLog("Error taking snapshot for camera: \(url). Error: \(errorMessage)")
                        }
                        completion(TakeSnapshotIntentResponse(code: .failure, userActivity: nil))
                    }
                }
            } else {
                NSLog("Error taking snapshot. Invalid camera URL: \(url)")
                completion(TakeSnapshotIntentResponse(code: .failure, userActivity: nil))
            }
        } else {
            completion(TakeSnapshotIntentResponse(code: .failure, userActivity: nil))
        }
    }
}
