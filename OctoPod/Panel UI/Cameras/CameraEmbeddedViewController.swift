import UIKit
import SafariServices  // Used for opening browser in-app

class CameraEmbeddedViewController: UIViewController, OctoPrintSettingsDelegate, OctoPrintPluginsDelegate, UIScrollViewDelegate {

    private static let CAMERA_INFO_GESTURES = "CAMERA_INFO_GESTURES"

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()

    @IBOutlet weak var topCameraLabel: UILabel!
    @IBOutlet weak var printTimeLeftLabel: UILabel!
    @IBOutlet weak var tool0ActualLabel: UILabel!
    @IBOutlet weak var bedActualLabel: UILabel!

    @IBOutlet weak var errorMessageLabel: UILabel!
    @IBOutlet weak var errorURLButton: UIButton!
    
    @IBOutlet weak var tapMessageLabel: UILabel!
    @IBOutlet weak var pinchMessageLabel: UILabel!
    
    @IBOutlet weak var octolightHAButton: UIButton!
    
    var printerURL: String? // URL to core data printer object. Only when not displaying default printer
    var cameraLabel: String?
    var cameraURL: String!
    var cameraOrientation: UIImage.Orientation!
    
    var cameraTappedCallback: ((CameraEmbeddedViewController) -> Void)?
    var cameraViewDelegate: CameraViewDelegate?
    var cameraIndex: Int!
    var cameraRatio: CGFloat?
    var muteVideo = false
    var muteAvailable = false

    var infoGesturesAvailable: Bool = false // Flag that indicates if page wants to instruct user that gestures are available for full screen and zoom in/out
    
    var camerasViewController: CamerasViewController?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Start listening to events when app comes back from background
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.didBecomeActiveNotification, object: nil)
        // Listen when app went to background so we can stop any ongoing HTTP request
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)

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

        // Add a gesture recognizer to camera view so we can handle taps
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleCameraTap))
        gestureView().isUserInteractionEnabled = true
        gestureView().addGestureRecognizer(tapGesture)

        renderPrinter(appActive: UIApplication.shared.applicationState != .background)
        
        // Listen to changes to OctoPrint Plugin messages
        octoprintClient.octoPrintPluginsDelegates.append(self)

        // Listen to changes to OctoPrint Settings in case the camera orientation has changed
        octoprintClient.octoPrintSettingsDelegates.append(self)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Stop listening to events when app comes back from background
        NotificationCenter.default.removeObserver(self)

        // Stop listening to changes to OctoPrint Plugin messages
        octoprintClient.remove(octoPrintPluginsDelegate: self)

        // Stop listening to changes to OctoPrint Settings
        octoprintClient.remove(octoPrintSettingsDelegate: self)

        stopRenderingPrinter()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Hide display printer status (so when it comes back there is no old info)
        displayPrintStatus(enabled: false)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func stopRenderingPrinter() {
        stopPlaying()
    }
    
    func displayPrintStatus(enabled: Bool) {
        DispatchQueue.main.async {
            if let _ = self.parent {
                self.printTimeLeftLabel.isHidden = !enabled
                self.tool0ActualLabel.isHidden = !enabled
                self.bedActualLabel.isHidden = !enabled
                if enabled {
                    // Reset values in case they are old
                    self.printTimeLeftLabel.text = ""
                    self.tool0ActualLabel.text = ""
                    self.bedActualLabel.text = ""
                }
            }
        }
    }
    
    // MARK: - Notifications

    func printerSelectedChanged() {
        renderPrinter(appActive: UIApplication.shared.applicationState == .active)
    }
    
    func cameraSelectedChanged() {
        renderPrinter(appActive: UIApplication.shared.applicationState == .active)
    }
    
    func currentStateUpdated(event: CurrentStateEvent) {
        DispatchQueue.main.async {
            if let _ = self.parent {
                if let seconds = event.progressPrintTimeLeft {
                    self.printTimeLeftLabel.text = UIUtils.secondsToTimeLeft(seconds: seconds, includesApproximationPhrase: true, ifZero: "")
                } else if event.progressPrintTime != nil {
                    self.printTimeLeftLabel.text = NSLocalizedString("Still stabilizing", comment: "Print time is being calculated")
                }

                if let tool0Actual = event.tool0TempActual {
                    self.tool0ActualLabel.text = "\(String(format: "%.1f", tool0Actual))C"
                }
                if let bedActual = event.bedTempActual {
                    self.bedActualLabel.text = "\(String(format: "%.1f", bedActual))C"
                }
            }
        }
    }
    
    // MARK: - Button actions

    @IBAction func errorURLClicked(_ sender: Any) {
        if let url = URL(string: cameraURL), UIApplication.shared.canOpenURL(url) {
            let svc = SFSafariViewController(url: url)
            UIApplication.shared.keyWindow?.rootViewController?.present(svc, animated: true, completion: nil)
        }
    }
    
    @IBAction func octolightHAClicked(_ sender: Any) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()

        octoprintClient.toggleOctoLightHA { (on: Bool?, error: (any Error)?, response: HTTPURLResponse) in
            if let error = error {
                NSLog("Error requesting toggle power of HA light: \(String(describing: error.localizedDescription)). Http response: \(response.statusCode)")
            }
            if let isLightOn = on {
                DispatchQueue.main.async {
                    self.displayOctoLightHAButton(isLightOn: isLightOn)
                    generator.notificationOccurred(.success)
                }
            } else {
                NSLog("Error requesting to toggle light \(String(describing: error?.localizedDescription)). Http response: \(response.statusCode)")
                self.showAlert(NSLocalizedString("Light", comment: ""), message: NSLocalizedString("Failed to toggle light", comment: ""))
            }
        }
    }
    
    // MARK: - Navigation
    
    @objc func handleCameraTap() {
        // Record that user used this feature
        userUsedGestures()
        
        if let callback = cameraTappedCallback {
            callback(self)
        }
    }

    // MARK: - OctoPrintSettingsDelegate
    
    func sdSupportChanged(sdSupport: Bool) {
        // Do nothing
    }
    
    func cameraOrientationChanged(newOrientation: UIImage.Orientation) {
        setCameraOrientation(newOrientation: newOrientation)
    }
    
    func camerasChanged(camerasURLs: Array<String>) {
        // Do nothing. Parent view controller will take care of this
    }
    
    func octolightHAAvailabilityChanged(installed: Bool) {
        DispatchQueue.main.async {
            if let printer = self.targetPrinter() {
            // Display octoLightHA button if plugin is installed
            self.octolightHAButton.isHidden = !printer.octolightHAInstalled
            }
        }
    }
    
    // MARK: - OctoPrintPluginsDelegate
    
    func pluginMessage(plugin: String, data: NSDictionary) {
        if plugin == Plugins.OCTO_LIGHT_HA {
            if let isLightOn = data["isLightOn"] as? Bool {
                DispatchQueue.main.async {
                    self.displayOctoLightHAButton(isLightOn: isLightOn)
                }
            }
        }
    }
    
    // MARK: - UIScrollViewDelegate
    
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

    func renderPrinter(appActive: Bool) {
        // Hide error messages
        errorMessageLabel.isHidden = true
        errorURLButton.isHidden = true
        
        // Hide OctoLight HomeAssistant Button until we know this plugin is installed
        octolightHAButton.isHidden = true
        
        if let printer = targetPrinter() {
            
            setCameraOrientation(newOrientation: cameraOrientation)

            if let url = URL(string: cameraURL.trimmingCharacters(in: .whitespaces)) {
                // Make sure that url button is clickable (visible when not hidden)
                self.errorURLButton.isUserInteractionEnabled = true
                
                if appActive {
                    // Only render camera when running in foreground (this will save some battery and network/cell usage)
                    renderPrinter(printer: printer, url: url)
                    if printer.octolightHAInstalled {
                        // Display octoLightHA button if plugin is installed
                        octolightHAButton.isHidden = false
                        // Fetch status of the HomeAssistant Light
                        octoprintClient.getOctoLightHAState { (on: Bool?, error: (any Error)?, response: HTTPURLResponse) in
                            if let error = error {
                                NSLog("Error requesting HA light status: \(String(describing: error.localizedDescription)). Http response: \(response.statusCode)")
                            }
                            if let isLightOn = on {
                                DispatchQueue.main.async {
                                    self.displayOctoLightHAButton(isLightOn: isLightOn)
                                }
                            }
                        }
                    }
                }

            } else {
                // Camera URL was not valid (e.g. url string contains characters that are illegal in a URL, or is an empty string)
                self.errorMessageLabel.text = NSLocalizedString("Invalid camera URL", comment: "URL of camera is invalid")
                self.errorMessageLabel.numberOfLines = 1
                self.errorURLButton.setTitle(self.cameraURL, for: .normal)
                self.errorMessageLabel.isHidden = false
                self.errorURLButton.isHidden = false
                self.errorURLButton.isUserInteractionEnabled = false
            }
        }
    }

    fileprivate func userUsedGestures() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: CameraEmbeddedViewController.CAMERA_INFO_GESTURES)
    }
    
    fileprivate func targetPrinter() -> Printer? {
        // If there is a target printer then display this printer
        if let url = self.printerURL, let idURL = URL(string: url) {
            return printerManager.getPrinterByObjectURL(url: idURL)
        } else {
            // Use default printer if not
            return printerManager.getDefaultPrinter()
        }
    }

    fileprivate func displayOctoLightHAButton(isLightOn: Bool) {
        self.octolightHAButton.setImage(isLightOn ? UIImage(named: "Light_Off") : UIImage(named: "Light_On"), for: .normal)
    }
    
    fileprivate func showAlert(_ title: String, message: String) {
        UIUtils.showAlert(presenter: self, title: title, message: message, done: nil)
    }
    
    @objc func appWillEnterForeground() {
        // Resume rendering printer
        renderPrinter(appActive: true)
    }
    
    @objc func appDidEnterBackground() {
        stopPlaying()
    }
    
    // MARK: - Abstract methods
    
    func setCameraOrientation(newOrientation: UIImage.Orientation) {
    }

    func renderPrinter(printer: Printer, url: URL) {
    }

    func stopPlaying() {
    }
    
    func gestureView() -> UIView {
        // Dummy return that will never execute
        return view
    }

    func destroy() {
    }
}
