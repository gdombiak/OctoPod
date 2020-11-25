import Foundation
import UIKit

class CameraService: ObservableObject {
    @Published var image: UIImage?
    @Published var imageRatio: CGFloat?
    @Published var errorMessage: String?
    
    private var cameraURL: String!
    private var cameraOrientation: Int!
    private var username: String?
    private var password: String?
    
    private var streamingController: MjpegStreamingController!
    private var hlsThumbnailGenerator: HLSThumbnailUtil?

    init(cameraURL: String, cameraOrientation: Int, username: String?, password: String?) {
        self.cameraURL = cameraURL
        self.cameraOrientation = cameraOrientation
        self.username = username
        self.password = password
        self.streamingController = MjpegStreamingController()
        self.streamingController.timeoutInterval = 2 // Timeout fast so widget does not fail to render in case of an error
    }
    
    func renderImage(completion: @escaping () -> ()) {
        if let url = URL(string: cameraURL) {
            if UIUtils.isHLS(url: cameraURL) {
                renderHLSImage(cameraURL: url, completion: completion)
            } else {
                renderMJPEGImage(cameraURL: url, completion: completion)
            }
        } else {
            self.image = nil
            // Display error messages
            self.errorMessage = NSLocalizedString("No camera", comment: "No camera was configured")
            // Execute completion block when done
            completion()
        }
    }
    
    // MARK: - Private functions

    fileprivate func renderMJPEGImage(cameraURL: URL, completion: @escaping () -> ()) {
        // User authentication credentials if configured for the printer
        if let username = self.username, let password = self.password {
            // Handle user authentication if webcam is configured this way (I hope people are being careful and doing this)
            streamingController.authenticationHandler = { challenge in
                let credential = URLCredential(user: username, password: password, persistence: .forSession)
                return (.useCredential, credential)
            }
        }
        
        streamingController.authenticationFailedHandler = {
            DispatchQueue.main.async {
                self.image = nil
                // Display error messages
                self.errorMessage = NSLocalizedString("Authentication failed", comment: "HTTP authentication failed")
                // Execute completion block when done
                completion()
            }
        }
        
        streamingController.didFinishWithErrors = { error in
            DispatchQueue.main.async {
                self.image = nil
                // Display error messages
                self.errorMessage = error.localizedDescription
                // Execute completion block when done
                completion()
            }
        }
        
        streamingController.didFinishWithHTTPErrors = { httpResponse in
            // We got a 404 or some 5XX error
            DispatchQueue.main.async {
                self.image = nil
                // Display error messages
                self.errorMessage = String(format: NSLocalizedString("HTTP Request error", comment: "HTTP Request error info"), httpResponse.statusCode)
                // Execute completion block when done
                completion()
            }
        }

        streamingController.didRenderImage = { (image: UIImage) in
            // Stop loading next jpeg image (MJPEG is a stream of jpegs)
            self.streamingController.stop()
            DispatchQueue.main.async {
                // Notify that we got our first image and we know its ratio
                self.image = image
                self.imageRatio = image.size.height / image.size.width
                // Execute completion block when done
                completion()
            }
        }

        streamingController.imageOrientation = UIImage.Orientation(rawValue: self.cameraOrientation)!
        // Get first image and then stop streaming next images
        streamingController.play(url: cameraURL)
    }
    
    fileprivate func renderHLSImage(cameraURL: URL, completion: @escaping () -> ()) {
        hlsThumbnailGenerator = HLSThumbnailUtil(url: cameraURL, username: username, password: password) { (image: UIImage?) in
            if let image = image {
                DispatchQueue.main.async {
                    // Notify that we got our first image and we know its ratio
                    self.image = image
                    self.imageRatio = image.size.height / image.size.width
                    // Execute completion block when done
                    completion()
                }
            } else {
                DispatchQueue.main.async {
                    self.image = nil
                    // Display error messages
                    self.errorMessage = "No thumbnail generated"
                    // Execute completion block when done
                    completion()
                }
            }
        }
        hlsThumbnailGenerator!.generate()
    }
}
