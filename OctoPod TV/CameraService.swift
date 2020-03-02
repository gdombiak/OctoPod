import Foundation
import UIKit

struct Camera {
    var index: Int
    var url: String
    var orientation: UIImage.Orientation
}

class CameraService: ObservableObject {
    @Published var image: UIImage?
    @Published var imageRatio: CGFloat?
    @Published var errorMessage: String?
    @Published var hasNext: Bool = false
    @Published var hasPrevious: Bool = false
    
    private var streamingController = MjpegStreamingController()
    private var cameras: Array<Camera> = Array()
    private var cameraIndex = 0
    
    /// Render next camera
    func renderNext() {
        renderCamera(index: cameraIndex + 1)
    }

    /// Render previous camera
    func renderPrevious() {
        renderCamera(index: cameraIndex - 1)
    }

    // MARK: - Connection handling

    func connectToServer(printer: Printer) {
        initCameras(printer: printer)
        
        // User authentication credentials if configured for the printer
        if let username = printer.username, let password = printer.password {
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
            }
        }
        
        streamingController.didFinishWithErrors = { error in
            DispatchQueue.main.async {
                self.image = nil
                // Display error messages
                self.errorMessage = error.localizedDescription
            }
        }
        
        streamingController.didFinishWithHTTPErrors = { httpResponse in
            // We got a 404 or some 5XX error
            DispatchQueue.main.async {
                self.image = nil
                // Display error messages
                if httpResponse.statusCode == 503 && !printer.isStreamPathFromSettings() {
                    // If URL to camera was not returned via /api/settings and
                    // we got a 503 to the best guessed URL then show "no camera" error message
                    self.errorMessage = NSLocalizedString("No camera", comment: "No camera was found")
                } else {
                    self.errorMessage = String(format: NSLocalizedString("HTTP Request error", comment: "HTTP Request error info"), httpResponse.statusCode)
                }
            }
        }

        streamingController.didFetchImage = { (image: UIImage) in
            DispatchQueue.main.async {
                // Notify that we got our first image and we know its ratio
                self.image = image
                self.imageRatio = image.size.height / image.size.width
            }
        }

        streamingController.didFinishLoading = {
            DispatchQueue.main.async {
                // Hide error messages since an image will be rendered (so that means that it worked!)
                self.errorMessage = nil
            }
        }
        
        // Start rendering the last selected camera
        renderCamera(index: cameraIndex)
    }
    
    func disconnectFromServer() {
        streamingController.stop()
    }
    
    // MARK: - Private functions

    /// Stops rendering any previous URL and starts rendering the requested camera
    /// Needs to be called from main thread
    fileprivate func renderCamera(index: Int) {
        cameraIndex = index
        hasNext = cameras.count > index + 1
        hasPrevious = index > 0

        if let url = URL(string: cameras[index].url.trimmingCharacters(in: .whitespaces)) {
            streamingController.imageOrientation = cameras[index].orientation
            streamingController.play(url: url)
        } else {
            // Camera URL was not valid (e.g. url string contains characters that are illegal in a URL, or is an empty string)
            self.errorMessage = NSLocalizedString("Invalid camera URL", comment: "URL of camera is invalid")
        }
    }
    
    /// Discover and store number of cameras, their URL and image orientation
    fileprivate func initCameras(printer: Printer) {
        cameras = Array()
        
        if let camerasURLs = printer.cameras {
            // MultiCam plugin is installed so show all cameras
            var index = 0
            for url in camerasURLs {
                var cameraOrientation: UIImage.Orientation
                var cameraURL: String
                
                if url == printer.getStreamPath() {
                    // This is camera hosted by OctoPrint so respect orientation
                    cameraURL = octoPrintCameraAbsoluteUrl(hostname: printer.hostname, streamUrl: url)
                    cameraOrientation = UIImage.Orientation(rawValue: Int(printer.cameraOrientation))!
                } else {
                    if url.starts(with: "/") {
                        // Another camera hosted by OctoPrint so build absolute URL
                        cameraURL = octoPrintCameraAbsoluteUrl(hostname: printer.hostname, streamUrl: url)
                    } else {
                        // Use absolute URL to render camera
                        cameraURL = url
                    }
                    cameraOrientation = UIImage.Orientation.up // MultiCam has no information about orientation of extra cameras so assume "normal" position - no flips
                }
        
                cameras.append(Camera(index: index, url: cameraURL, orientation: cameraOrientation))
                index = index + 1
            }
        }
        if cameras.isEmpty {
            // MultiCam plugin is not installed so just show default camera
            let cameraURL = octoPrintCameraAbsoluteUrl(hostname: printer.hostname, streamUrl: printer.getStreamPath())
            let cameraOrientation = UIImage.Orientation(rawValue: Int(printer.cameraOrientation))!
            cameras.append(Camera(index: 0, url: cameraURL, orientation: cameraOrientation))
        }
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
