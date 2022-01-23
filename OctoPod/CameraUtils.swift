import Foundation
import UIKit

class CameraUtils {
    
    /// Singleton instance of this class
    static let shared = CameraUtils()
    
    // We need to keep this as an instance variable so it is not garbage collected and crashes
    // the app since it uses KVO which crashes if observer has been GC'ed
    private var hlsThumbnailGenerator: HLSThumbnailUtil?
    
    private init() {
    }
    
    func renderImage(cameraURL: URL, imageOrientation: UIImage.Orientation, username: String?, password: String?, preemptive: Bool, timeoutInterval: TimeInterval?, completion: @escaping (UIImage?, String?) -> ()) {
        if isHLS(url: cameraURL.absoluteString) {
            renderHLSImage(cameraURL: cameraURL, imageOrientation: imageOrientation, username: username, password: password, completion: completion)
        } else {
            renderMJPEGImage(cameraURL: cameraURL, imageOrientation: imageOrientation, username: username, password: password, preemptive: preemptive, timeoutInterval: timeoutInterval, completion: completion)
        }
    }
    
    func isHLS(url: String) -> Bool {
        return url.hasSuffix(".m3u8")
    }
    
    func absoluteURL(hostname: String, streamUrl: String) -> String {
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

    // MARK: - Private functions
    
    fileprivate func renderMJPEGImage(cameraURL: URL, imageOrientation: UIImage.Orientation, username: String?, password: String?, preemptive: Bool, timeoutInterval: TimeInterval?, completion: @escaping (UIImage?, String?) -> ()) {
        let streamingController = MjpegStreamingController()
        
        if let timeout = timeoutInterval {
            streamingController.timeoutInterval = timeout
        }

        if let username = username, let password = password {
            // User authentication credentials if configured for the printer
            if preemptive {
                streamingController.authorizationHeader = HTTPClient.authBasicHeader(username: username, password: password)
            } else {
                streamingController.authenticationHandler = { challenge in
                    let credential = URLCredential(user: username, password: password, persistence: .forSession)
                    return (.useCredential, credential)
                }
            }
        }
        
        streamingController.authenticationFailedHandler = {
            let message = NSLocalizedString("Authentication failed", comment: "HTTP authentication failed")
            completion(nil, message)
        }

        streamingController.didFinishWithErrors = { error in
            completion(nil, error.localizedDescription)
        }
        
        streamingController.didFinishWithHTTPErrors = { httpResponse in
            let message: String
            if httpResponse.statusCode == 609 {
                message = NSLocalizedString("OctoEverywhere: Webcam Limit Exceeded", comment: "Error message from OctoEverywhere")
            } else {
                // We got a 404 or some 5XX error
                message = String(format: NSLocalizedString("HTTP Request error", comment: "HTTP Request error info"), httpResponse.statusCode)
            }
            completion(nil, message)
        }

        streamingController.didReceiveJSON = { (json: NSDictionary) in
            NSLog("No image received. Received JSON: \(json)")
            let message: String
            if let host = cameraURL.host, host.hasSuffix("thespaghettidetective.com") {
                message = NSLocalizedString("The Detective Is Not Watching", comment: "The Spaghetti Detective Is Not Watching")
            } else {
                message = NSLocalizedString("No image is available", comment: "")
            }
            completion(nil, message)
        }

        streamingController.didRenderImage = { (image: UIImage) in
            // Stop loading next jpeg image (MJPEG is a stream of jpegs)
            streamingController.stop()
            completion(image, nil)
        }

        streamingController.imageOrientation = imageOrientation
        // Get first image and then stop streaming next images
        streamingController.play(url: cameraURL)
    }
    
    fileprivate func renderHLSImage(cameraURL: URL, imageOrientation: UIImage.Orientation, username: String?, password: String?, completion: @escaping (UIImage?, String?) -> ()) {
        hlsThumbnailGenerator = HLSThumbnailUtil(url: cameraURL, imageOrientation: imageOrientation, username: username, password: password) { (image: UIImage?) in
            if let image = image {
                // Execute completion block when done
                completion(image, nil)
            } else {
                // Execute completion block when done
                completion(nil, "No thumbnail generated")
            }
        }
        hlsThumbnailGenerator!.generate()
    }
}
