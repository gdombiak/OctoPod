import UIKit
import Foundation

class CameraTSDEmbeddedViewController: CameraEmbeddedViewController {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var countdownProgressView: CircularProgressBarView!
    
    private var username: String?
    private var password: String?
    
    private var timer: Timer?
    private var countdown = 0
 
    override func viewDidLoad() {
        super.viewDidLoad()
        
        countdownProgressView.backgroundColor = UIColor.lightGray.withAlphaComponent(0.2)
        countdownProgressView.layer.cornerRadius = 6
    }
    
    // MARK: - UIScrollViewDelegate

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    // MARK: - Abstract methods
    
    override func renderPrinter(printer: Printer, url: URL) {
        // Store creds that will be needed to fetch snapshot URL that changes every 10 seconds
        username = printer.username
        password = printer.password
        // invalidate previous timer
        timer?.invalidate()
        // Refresh now (we can safely change this variable here since timer is stopped)
        self.countdown = 0
        // Create new timer
        timer = Timer(fire: Date(), interval: 1, repeats: true, block: { (timer: Timer) in
            if self.countdown == 0 {
                // We need to make call Webcam snapshot API to then fetch Image from returned URL
                if let url = URL(string: self.cameraURL) {
                    CameraUtils.shared.renderImage(cameraURL: url, imageOrientation: self.cameraOrientation, username: self.username, password: self.password, preemptive: printer.preemptiveAuthentication(), timeoutInterval: 5.0) { (image: UIImage?, error: String?) in
                        if let receivedImage = image {
                            DispatchQueue.main.async {
                                // Hide error messages since an image will be rendered (so that means that it worked!)
                                self.errorMessageLabel.isHidden = true
                                self.errorURLButton.isHidden = true
                                // Update image
                                self.imageView.image = receivedImage
                            }
                            // Notify that we got our first image and we know its ratio
                            self.cameraViewDelegate?.imageAspectRatio(cameraIndex: self.cameraIndex, ratio: receivedImage.size.height / receivedImage.size.width)
                        } else if let message = error {
                            DispatchQueue.main.async {
                                self.imageView.image = nil
                                // Display error messages
                                self.errorMessageLabel.text = message
                                self.errorMessageLabel.numberOfLines = 2
                                self.errorMessageLabel.isHidden = false
                                self.errorURLButton.isHidden = true
                            }
                        }
                    }
                }
                // Reset counter to 10 seconds since image changes every 10 seconds
                self.countdown = 10
            } else {
                self.countdown -= 1
            }
            DispatchQueue.main.async {
                self.countdownProgressView.showProgress(percent: Float(self.countdown * 10))
            }
        })
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    override func setCameraOrientation(newOrientation: UIImage.Orientation) {
        self.cameraOrientation = newOrientation
//        if newOrientation == UIImage.Orientation.left || newOrientation == UIImage.Orientation.leftMirrored || newOrientation == UIImage.Orientation.rightMirrored || newOrientation == UIImage.Orientation.right {
//            DispatchQueue.main.async {
//                self.imageView.contentMode = .scaleAspectFit
//            }
//        } else {
//            DispatchQueue.main.async {
//                self.imageView.contentMode = .scaleAspectFit
//            }
//        }
    }
    
    override func stopPlaying() {
        timer?.invalidate()
    }
    
    override func gestureView() -> UIView {
        return imageView
    }
}
