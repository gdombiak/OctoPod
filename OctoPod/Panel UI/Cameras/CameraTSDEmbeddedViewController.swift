import UIKit
import Foundation

class CameraTSDEmbeddedViewController: CameraEmbeddedViewController {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var countdownLabel: UILabel!
    
    private var username: String?
    private var password: String?
    
    private var timer: Timer?
    private var countdown = 0
 
    override func viewDidLoad() {
        super.viewDidLoad()
        
        countdownLabel.layer.cornerRadius = 6
        countdownLabel.layer.masksToBounds = true
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
                self.fetchSnapshotURLAndImage()
                // Reset counter to 10 seconds since image changes every 10 seconds
                self.countdown = 10
            } else {
                self.countdown -= 1
            }
            DispatchQueue.main.async {
                self.countdownLabel.text = "\(self.countdown)"
                self.countdownLabel.isHidden = self.countdown == 0
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
    
    // MARK: - Private functions
    
    fileprivate func fetchImage(_ imageURL: URL) {
        let imageURLRequest = URLRequest(url: imageURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 5.0)
        URLSession.shared.dataTask(with: imageURLRequest) { (data: Data?, response: URLResponse?, error: Error?) in
            if let imageData = data , imageData.count > 0, var receivedImage = UIImage(data: imageData) {
                if let cgImage = receivedImage.cgImage, self.cameraOrientation != UIImage.Orientation.up {
                    // Rotate image based on requested orientation
                    receivedImage = UIImage(cgImage: cgImage, scale: CGFloat(1.0), orientation: self.cameraOrientation)
                }
                DispatchQueue.main.async {
                    // Hide error messages since an image will be rendered (so that means that it worked!)
                    self.errorMessageLabel.isHidden = true
                    self.errorURLButton.isHidden = true
                    // Update image
                    self.imageView.image = receivedImage
                }
                // Notify that we got our first image and we know its ratio
                self.cameraViewDelegate?.imageAspectRatio(cameraIndex: self.cameraIndex, ratio: receivedImage.size.height / receivedImage.size.width)
            } else if let error = error {
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
        }.resume()
    }
    
    fileprivate func fetchSnapshotURLAndImage() {
        if let url = URL(string: cameraURL), let username = username, let password = password {
            var urlRequest = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 5.0)
            urlRequest.setValue(HTTPClient.authBasicHeader(username: username, password: password), forHTTPHeaderField: "Authorization")
            URLSession.shared.dataTask(with: urlRequest) { (data: Data?, response: URLResponse?, error: Error?) in
                if let data = data {
                    do {
                        let snapshotResponse = try JSONDecoder().decode(TSDSnapshotResponse.self, from: data)
                        if let snapshotURL = snapshotResponse.snapshot, let imageURL = URL(string: snapshotURL) {
                            // Fetch and display Image from returned URL
                            self.fetchImage(imageURL)
                        } else {
                            DispatchQueue.main.async {
                                self.imageView.image = nil
                                self.errorMessageLabel.text = NSLocalizedString("The Detective Is Not Watching", comment: "The Spaghetti Detective Is Not Watching")
                                self.errorMessageLabel.numberOfLines = 2
                                self.errorMessageLabel.isHidden = false
                                self.errorURLButton.isHidden = true
                            }
                        }
                    } catch let error {
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
                }
            }.resume()
        }
    }

}

struct TSDSnapshotResponse: Codable {
    let snapshot: String?
}
