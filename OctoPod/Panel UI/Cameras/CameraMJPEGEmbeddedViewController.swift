import UIKit

class CameraMJPEGEmbeddedViewController: CameraEmbeddedViewController {
    @IBOutlet weak var imageView: UIImageView!
 
    var streamingController: MjpegStreamingController?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        streamingController = MjpegStreamingController(imageView: imageView)
    }
    
    // MARK: - UIScrollViewDelegate

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    // MARK: - Abstract methods

    override func renderPrinter(printer: Printer, url: URL) {
        var imageCount = 0
        
        // User authentication credentials if configured for the printer
        if let username = printer.username, let password = printer.password {
            if printer.preemptiveAuthentication() {
                streamingController?.authorizationHeader = HTTPClient.authBasicHeader(username: username, password: password)
            } else {
                // Handle user authentication if webcam is configured this way (I hope people are being careful and doing this)
                streamingController?.authenticationHandler = { challenge in
                    let credential = URLCredential(user: username, password: password, persistence: .forSession)
                    return (.useCredential, credential)
                }
            }
        }
        
        if printer.headers != nil {
            streamingController?.setHeaders(headers: printer.headers)
        }
        
        streamingController?.authenticationFailedHandler = {
            DispatchQueue.main.async {
                self.imageView.image = nil
                // Display error messages
                self.errorMessageLabel.text = NSLocalizedString("Authentication failed", comment: "HTTP authentication failed")
                self.errorMessageLabel.numberOfLines = 1
                self.errorMessageLabel.isHidden = false
            }
        }
        
        streamingController?.didFinishWithErrors = { error in
            DispatchQueue.main.async {
                self.imageView.image = nil
                // Display error messages
                self.errorMessageLabel.text = error.localizedDescription
                self.errorMessageLabel.numberOfLines = 2
                self.errorURLButton.setTitle(self.cameraURL, for: .normal)
                self.errorMessageLabel.isHidden = false
                self.errorURLButton.isHidden = false
            }
        }
        
        streamingController?.didFinishWithHTTPErrors = { httpResponse in
            // We got a 404 or some 5XX error
            DispatchQueue.main.async {
                self.imageView.image = nil
                // Display error messages
                if httpResponse.statusCode == 503 && !printer.isStreamPathFromSettings() {
                    // If URL to camera was not returned via /api/settings and
                    // we got a 503 to the best guessed URL then show "no camera" error message
                    self.errorMessageLabel.text = NSLocalizedString("No camera", comment: "No camera was found")
                    self.errorMessageLabel.numberOfLines = 1
                    self.errorMessageLabel.isHidden = false
                    self.errorURLButton.isHidden = true
                } else if httpResponse.statusCode == 605 {
                    self.errorMessageLabel.text = NSLocalizedString("Account is no longer an OctoEverywhere supporter", comment: "")
                    self.errorMessageLabel.numberOfLines = 2
                    self.errorMessageLabel.isHidden = false
                    self.errorURLButton.isHidden = true
                } else if httpResponse.statusCode == 609 {
                    self.errorMessageLabel.text = NSLocalizedString("OctoEverywhere: Webcam Limit Exceeded", comment: "Error message from OctoEverywhere")
                    self.errorMessageLabel.numberOfLines = 2
                    self.errorMessageLabel.isHidden = false
                    self.errorURLButton.isHidden = true
                } else {
                    self.errorMessageLabel.text = String(format: NSLocalizedString("HTTP Request error", comment: "HTTP Request error info"), httpResponse.statusCode)
                    self.errorMessageLabel.numberOfLines = 1
                    self.errorURLButton.setTitle(self.cameraURL, for: .normal)
                    self.errorMessageLabel.isHidden = false
                    self.errorURLButton.isHidden = false
                }
            }
        }
        
        streamingController?.didRenderImage = { (image: UIImage) in
            // Notify that we got our first image and we know its ratio
            self.cameraViewDelegate?.imageAspectRatio(cameraIndex: self.cameraIndex, ratio: image.size.height / image.size.width)
        }
        
        streamingController?.didFetchImage = { (image: UIImage) in
            imageCount += 1
            
//            if (imageCount < 50) {
//                NSLog("Check luminance of camera. Image: #\(imageCount) isDark: \(String(describing: image.luminanceBelow(threshold: 40)))")
//            }
            
            // Some cameras render a black image on startup for a brief moment
            // Skip a few images before checking if light is on/off
            if imageCount == 5 {
                self.checkRoomLuminance(image: image)
            }
        }

        streamingController?.didFinishLoading = {
            // Hide error messages since an image will be rendered (so that means that it worked!)
            self.errorMessageLabel.isHidden = true
            self.errorURLButton.isHidden = true
        }
        
        // Start rendering the camera
        streamingController?.play(url: url)
    }
    
    override func setCameraOrientation(newOrientation: UIImage.Orientation) {
        streamingController?.imageOrientation = newOrientation
        if newOrientation == UIImage.Orientation.left || newOrientation == UIImage.Orientation.leftMirrored || newOrientation == UIImage.Orientation.rightMirrored || newOrientation == UIImage.Orientation.right {
            DispatchQueue.main.async {
                self.imageView.contentMode = .scaleAspectFit
            }
        } else {
            DispatchQueue.main.async {
                self.imageView.contentMode = .scaleAspectFit
            }
        }
    }
    
    override func stopPlaying() {
        streamingController?.stop()
    }
    
    override func gestureView() -> UIView {
        return imageView
    }
    
    override func destroy() {
        streamingController?.destroy()
        streamingController = nil
    }
}
