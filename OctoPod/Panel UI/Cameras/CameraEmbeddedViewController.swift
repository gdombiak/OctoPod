import UIKit
import SafariServices  // Used for opening browser in-app

class CameraEmbeddedViewController: UIViewController, OctoPrintSettingsDelegate, UIScrollViewDelegate {

    private static let CAMERA_INFO_GESTURES = "CAMERA_INFO_GESTURES"

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()

    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var errorMessageLabel: UILabel!
    @IBOutlet weak var errorURLButton: UIButton!
    
    @IBOutlet weak var tapMessageLabel: UILabel!
    @IBOutlet weak var pinchMessageLabel: UILabel!
    
    var streamingController: MjpegStreamingController?
    
    var cameraURL: String!
    var cameraOrientation: UIImageOrientation!
    
    var embedded: Bool = true
    var embeddedCameraTappedCallback: (() -> Void)?

    var infoGesturesAvailable: Bool = false // Flag that indicates if page wants to instruct user that gestures are available for full screen and zoom in/out

    override func viewDidLoad() {
        super.viewDidLoad()

        streamingController = MjpegStreamingController(imageView: imageView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // Start listening to events when app comes back from background
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: Notification.Name.UIApplicationWillEnterForeground, object: nil)
        // Listen when app went to background so we can stop any ongoing HTTP request
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: Notification.Name.UIApplicationDidEnterBackground, object: nil)

        if !embedded {
            // Hide the navigation bar on the this view controller
            self.navigationController?.setNavigationBarHidden(true, animated: animated)
            
        } else {
            let defaults = UserDefaults.standard
            if defaults.bool(forKey: CameraEmbeddedViewController.CAMERA_INFO_GESTURES) {
                // User already used gestures so hide information labels
                tapMessageLabel.isHidden = true
                pinchMessageLabel.isHidden = true
            } else {
                // User did not use gestures so parent window decides if messages should be displayed
                tapMessageLabel.isHidden = !infoGesturesAvailable
                pinchMessageLabel.isHidden = !infoGesturesAvailable
            }
        }
        // Add a gesture recognizer to camera view so we can handle taps
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleCameraTap))
        imageView.isUserInteractionEnabled = true
        imageView.addGestureRecognizer(tapGesture)

        renderPrinter()
        
        // Listen to changes to OctoPrint Settings in case the camera orientation has changed
        octoprintClient.octoPrintSettingsDelegates.append(self)
    }

    override func viewWillDisappear(_ animated: Bool) {
        // Stop listening to events when app comes back from background
        NotificationCenter.default.removeObserver(self)

        // Stop listening to changes to OctoPrint Settings
        octoprintClient.remove(octoPrintSettingsDelegate: self)

        stopRenderingPrinter()
        
        if !embedded {
            // Show the navigation bar on other view controllers
            self.navigationController?.setNavigationBarHidden(false, animated: animated)

            // When running full screen we are forcing landscape so we go back to portrait when leaving
            UIDevice.current.setValue(Int(UIInterfaceOrientation.portrait.rawValue), forKey: "orientation")
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Notifications

    func printerSelectedChanged() {
        renderPrinter()
    }
    
    func cameraSelectedChanged() {
        renderPrinter()
    }
    
    // MARK: - Button actions

    @IBAction func errorURLClicked(_ sender: Any) {
        let svc = SFSafariViewController(url: URL(string: cameraURL)!)
        UIApplication.shared.keyWindow?.rootViewController?.present(svc, animated: true, completion: nil)
    }
    
    // MARK: - Navigation
    
    @objc func handleCameraTap() {
        // Record that user used this feature
        userUsedGestures()
        
        if !embedded {
            navigationController?.popViewController(animated: true)
        } else if let callback = embeddedCameraTappedCallback {
            callback()
        }
    }

    // MARK: - OctoPrintSettingsDelegate
    
    // Notification that sd support has changed
    func sdSupportChanged(sdSupport: Bool) {
        // Do nothing
    }
    
    // Notification that orientation of the camera hosted by OctoPrint has changed
    func cameraOrientationChanged(newOrientation: UIImageOrientation) {
        setCameraOrientation(newOrientation: newOrientation)
    }
    
    // Notification that a new camera has been added or removed. We rely on MultiCam
    // plugin to be installed on OctoPrint so there is no need to re-enter this information
    // URL to cameras is returned in /api/settings under plugins->multicam
    func camerasChanged(camerasURLs: Array<String>) {
        // Do nothing. Parent view controller will take care of this
    }

    // MARK: - UIScrollViewDelegate
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        // Record that user used this feature
        userUsedGestures()

        if infoGesturesAvailable {
            // Hide info labels
            tapMessageLabel.isHidden = true
            pinchMessageLabel.isHidden = true
        }
    }
    
    // MARK: - Private functions

    fileprivate func renderPrinter() {
        // Hide error messages
        errorMessageLabel.isHidden = true
        errorURLButton.isHidden = true
        
        if let printer = printerManager.getDefaultPrinter() {
            
            setCameraOrientation(newOrientation: cameraOrientation)

            let url = URL(string: cameraURL)
            
            // User authentication credentials if configured for the printer
            if let username = printer.username, let password = printer.password {
                // Handle user authentication if webcam is configured this way (I hope people are being careful and doing this)
                streamingController?.authenticationHandler = { challenge in
                    let credential = URLCredential(user: username, password: password, persistence: .forSession)
                    return (.useCredential, credential)
                }
            }

            streamingController?.authenticationFailedHandler = {
                DispatchQueue.main.async {
                    self.imageView.image = nil
                    // Display error messages
                    self.errorMessageLabel.text = "Authentication failed"
                    self.errorMessageLabel.isHidden = false
                }
            }
            
            streamingController?.didFinishWithErrors = { error in
                DispatchQueue.main.async {
                    self.imageView.image = nil
                    // Display error messages
                    self.errorMessageLabel.text = error.localizedDescription
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
                        self.errorMessageLabel.text = "No camera"
                        self.errorMessageLabel.isHidden = false
                        self.errorURLButton.isHidden = true
                    } else {
                        self.errorMessageLabel.text = "Request error. HTTP response: \(httpResponse.statusCode)"
                        self.errorURLButton.setTitle(self.cameraURL, for: .normal)
                        self.errorMessageLabel.isHidden = false
                        self.errorURLButton.isHidden = false
                    }
                }
            }
            
            streamingController?.didFinishLoading = {
                // Hide error messages since an image will be rendered (so that means that it worked!)
                self.errorMessageLabel.isHidden = true
                self.errorURLButton.isHidden = true
            }

            // Start rendering the camera
            streamingController?.play(url: url!)
        }
    }
    
    fileprivate func setCameraOrientation(newOrientation: UIImageOrientation) {
        streamingController?.imageOrientation = newOrientation
        if embedded {
            if newOrientation == UIImageOrientation.left || newOrientation == UIImageOrientation.leftMirrored || newOrientation == UIImageOrientation.rightMirrored || newOrientation == UIImageOrientation.right {
                DispatchQueue.main.async {
                    self.imageView.contentMode = .scaleAspectFit
                }
            } else {
                DispatchQueue.main.async {
                    self.imageView.contentMode = .scaleToFill
                }
            }
        }
    }
    
    fileprivate func stopRenderingPrinter() {
        streamingController?.stop()
    }
    
    fileprivate func userUsedGestures() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: CameraEmbeddedViewController.CAMERA_INFO_GESTURES)
    }

    @objc func appWillEnterForeground() {
        // Resume rendering printer
        renderPrinter()
    }
    
    @objc func appDidEnterBackground() {
        streamingController?.stop()
    }
}
