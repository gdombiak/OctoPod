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
            // Render image from HLS camera
            renderHLSImage(cameraURL: cameraURL, imageOrientation: imageOrientation, username: username, password: password, completion: completion)
        } else if let host = cameraURL.host, host.hasSuffix("thespaghettidetective.com") {
            // The Spaghetti Detective has its own special logic
            renderTLSImage(cameraURL: cameraURL, imageOrientation: imageOrientation, username: username, password: password, preemptive: preemptive, timeoutInterval: timeoutInterval, completion: completion)
        } else {
            // Render image from classic MJPEG camera
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

    fileprivate func renderTLSImage(cameraURL: URL, imageOrientation: UIImage.Orientation, username: String?, password: String?, preemptive: Bool, timeoutInterval: TimeInterval?, completion: @escaping (UIImage?, String?) -> ()) {
        
        struct TSDSnapshotResponse: Codable {
            let snapshot: String?
        }
        
        if let username = username, let password = password {
            var urlRequest = URLRequest(url: cameraURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: timeoutInterval ?? 5.0)
            urlRequest.setValue(HTTPClient.authBasicHeader(username: username, password: password), forHTTPHeaderField: "Authorization")
            URLSession.shared.dataTask(with: urlRequest) { (data: Data?, response: URLResponse?, error: Error?) in
                if let response = response as? HTTPURLResponse, let data = data {
                    if response.statusCode == 200 {
                        do {
                            let snapshotResponse = try JSONDecoder().decode(TSDSnapshotResponse.self, from: data)
                            if let snapshotURL = snapshotResponse.snapshot, let imageURL = URL(string: snapshotURL) {
                                // Fetch and display Image from returned URL
                                self.fetchTLSImage(imageURL: imageURL, imageOrientation: imageOrientation, timeoutInterval: timeoutInterval, completion: completion)
                            } else {
                                completion(nil, NSLocalizedString("The Detective Is Not Watching", comment: "The Spaghetti Detective Is Not Watching"))
                            }
                        } catch let error {
                            completion(nil, error.localizedDescription)
                        }
                    } else if response.statusCode == 401 {
                        completion(nil, NSLocalizedString("Authentication failed", comment: "HTTP authentication failed"))
                    } else {
                        completion(nil, String(format: NSLocalizedString("HTTP Request error", comment: "HTTP Request error info"), response.statusCode))
                    }
                }
            }.resume()
        }
    }

    fileprivate func fetchTLSImage(imageURL: URL, imageOrientation: UIImage.Orientation, timeoutInterval: TimeInterval?, completion: @escaping (UIImage?, String?) -> ()) {
        let imageURLRequest = URLRequest(url: imageURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 5.0)
        URLSession.shared.dataTask(with: imageURLRequest) { (data: Data?, response: URLResponse?, error: Error?) in
            if let imageData = data , imageData.count > 0, var receivedImage = UIImage(data: imageData) {
                if let cgImage = receivedImage.cgImage, imageOrientation != UIImage.Orientation.up {
                    // Rotate image based on requested orientation
                    receivedImage = UIImage(cgImage: cgImage, scale: CGFloat(1.0), orientation: imageOrientation)
                }
                completion(receivedImage, nil)
            } else if let error = error {
                completion(nil, error.localizedDescription)
            }
        }.resume()
    }
}
