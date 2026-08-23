import UIKit
import CoreMotion
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
    @IBOutlet weak var retryButton: UIButton!

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

    // Variables for exponential backoff. Used for retrying reloading camera when dealing with timeout
    var retryCount = 0
    var maxRetries = 10
    var baseRetryDelay: TimeInterval = 1.0
    var retryWorkItem: DispatchWorkItem?

    var infoGesturesAvailable: Bool = false // Flag that indicates if page wants to instruct user that gestures are available for full screen and zoom in/out
    
    var camerasViewController: CamerasViewController?

    /// Physical orientation captured before fullscreen forces the interface to landscape.
    var fullscreenPhysicalOrientationHint: UIDeviceOrientation?
    /// Set when fullscreen used the iOS 15 `UIDevice.setValue` force, which mutates `UIDevice.orientation`.
    var usedLegacyDeviceOrientationForce = false

    private var isTrackingPhysicalOrientationForStatusOverlay = false
    private var lastValidPhysicalOrientation: UIDeviceOrientation = .landscapeLeft
    private var overlayMotionManager: CMMotionManager?
    private var isGeneratingDeviceOrientationNotificationsForOverlay = false
    private var didReceiveUsableOverlayMotion = false
    private var didFallbackFromMotionToDeviceOrientation = false
    private var printStatusOverlayView: UIView?
    private var printStatusLabelsSuperview: UIView?
    private var printStatusLabelConstraints: [NSLayoutConstraint] = []
    private var printStatusOverlayInternalConstraints: [NSLayoutConstraint] = []
    private var suppressForcedLandscapeArtifactUntil: Date?
    private var isUpdatingPrintStatusOverlayPlacement = false

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updatePrintStatusOverlayPlacement()
    }

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
        
        // Reset number of retries attempted to render camera
        retryCount = 0

        renderPrinter(appActive: UIApplication.shared.applicationState != .background)
        
        // Listen to changes to OctoPrint Plugin messages
        octoprintClient.octoPrintPluginsDelegates.append(self)

        // Listen to changes to OctoPrint Settings in case the camera orientation has changed
        octoprintClient.octoPrintSettingsDelegates.append(self)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Cancel the exponential backoff when the view controller is about to disappear
        cancelRetryingRenderingCamera()

        stopPrintStatusOverlayPhysicalTracking()

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
                self.updatePrintStatusOverlayPlacement()
            }
        }
    }
    
    // MARK: - Notifications

    func printerSelectedChanged() {
        // Cancel any automatic retry of the camera (it uses exponential backoff) and reset counter of retries
        cancelRetryingRenderingCamera()

        renderPrinter(appActive: UIApplication.shared.applicationState == .active)
    }
    
    func cameraSelectedChanged() {
        // Cancel any automatic retry of the camera (it uses exponential backoff) and reset counter of retries
        cancelRetryingRenderingCamera()

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
                self.updatePrintStatusOverlayPlacement()
            }
        }
    }
    
    /// Check if there is enough room in the room. If room is dark and HA Light plugin is installed then turn on the light
    func checkRoomLuminance(image: UIImage) {
        if let isDark = image.luminanceBelow(threshold: 40), !self.octolightHAButton.isHidden && isDark {
            // Turn on HA light
            octoprintClient.turnOctoLightHA(on: true) { (on: Bool?, error: (any Error)?, response: HTTPURLResponse) in
                if let error = error {
                    NSLog("Error requesting to power HA light on: \(String(describing: error.localizedDescription)). Http response: \(response.statusCode)")
                }
                if let isLightOn = on {
                    DispatchQueue.main.async {
                        self.displayOctoLightHAButton(isLightOn: isLightOn)
                    }
                } else {
                    NSLog("Error requesting to power light on \(String(describing: error?.localizedDescription)). Http response: \(response.statusCode)")
                }
            }
        }
    }
    
    // MARK: - Button actions

    @IBAction func errorURLClicked(_ sender: Any) {
        if let url = URL(string: cameraURL), UIApplication.shared.canOpenURL(url) {
            let svc = SFSafariViewController(url: url)
            SceneInterfaceOrientation.presenter(for: self).present(svc, animated: true, completion: nil)
        }
    }
    
    @IBAction func retryClicked(_ sender: Any) {
        // Cancel any automatic retry of the camera (it uses exponential backoff) and reset counter of retries
        cancelRetryingRenderingCamera()
        
        // Retry rendering the camera again
        renderPrinter(appActive: true)
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
        retryButton.isHidden = true
        
        // Hide OctoLight HomeAssistant Button until we know this plugin is installed
        octolightHAButton.isHidden = true
        
        if let printer = targetPrinter() {
            
            setCameraOrientation(newOrientation: cameraOrientation)

            if let url = URL(string: cameraURL.trimmingCharacters(in: .whitespaces)) {
                // Make sure that url buttons are clickable (visible when not hidden)
                self.errorURLButton.isUserInteractionEnabled = true
                self.retryButton.isUserInteractionEnabled = true
                
                if appActive {
                    // Display octoLightHA button if plugin is installed
                    octolightHAButton.isHidden = !printer.octolightHAInstalled
                    // Only render camera when running in foreground (this will save some battery and network/cell usage)
                    renderPrinter(printer: printer, url: url)
                    if printer.octolightHAInstalled {
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
    
    func retryRenderingCamera() {
        // Increase number of times we are retrying to render the camera
        self.retryCount += 1
        if self.retryCount > self.maxRetries {
            // No more retries are left. Give up now
            return
        }

        // Create a WorkItem for the retry task with exponential backoff
        if retryWorkItem == nil {
            retryWorkItem = DispatchWorkItem { [weak self] in
                 guard let self = self else { return }

                 // Perform your task here
                self.renderPrinter(appActive: UIApplication.shared.applicationState != .background)
             }
        }
        let delay = self.baseRetryDelay * pow(2.0, Double(self.retryCount))
        NSLog("Will retry rendering camera after \(delay) seconds. Attempt #\(retryCount)")
        
        // Schedule to retry rendering the camera after the (exponential) delay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: self.retryWorkItem!)
    }
    
    fileprivate func cancelRetryingRenderingCamera() {
        retryWorkItem?.cancel()
        retryWorkItem = nil
        retryCount = 0
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
        // Cancel any automatic retry of the camera (it uses exponential backoff)
        cancelRetryingRenderingCamera()
        // Stop rendering the camera
        stopPlaying()
    }
    
    // MARK: - Abstract methods
    
    func setCameraOrientation(newOrientation: UIImage.Orientation) {
    }

    func setFullscreenPresentation(_ fullscreen: Bool) {
        if fullscreen {
            startPrintStatusOverlayPhysicalTracking()
        } else {
            stopPrintStatusOverlayPhysicalTracking()
        }
    }

    // MARK: - Fullscreen print-status overlay

    fileprivate func startPrintStatusOverlayPhysicalTracking() {
        if !isTrackingPhysicalOrientationForStatusOverlay {
            if let hint = fullscreenPhysicalOrientationHint, CameraFullscreenStatusOverlay.isValidPhysicalOrientation(hint) {
                lastValidPhysicalOrientation = hint
            } else {
                lastValidPhysicalOrientation = CameraFullscreenStatusOverlay.resolvedPhysicalOrientation(
                    UIDevice.current.orientation,
                    lastValid: lastValidPhysicalOrientation
                )
            }
            isTrackingPhysicalOrientationForStatusOverlay = true
            wrapPrintStatusOverlayIfNeeded()
            startFullscreenOverlayPhysicalSource()
            if CameraFullscreenStatusOverlay.shouldSuppressLegacyForcedLandscapeArtifact(
                usedLegacyDeviceOrientationForce: usedLegacyDeviceOrientationForce,
                lastValidPhysicalOrientation: lastValidPhysicalOrientation
            ) {
                suppressForcedLandscapeArtifactUntil = Date().addingTimeInterval(0.4)
            }
        }
        fullscreenPhysicalOrientationHint = nil
        usedLegacyDeviceOrientationForce = false
        updatePrintStatusOverlayPlacement()
    }

    fileprivate func stopPrintStatusOverlayPhysicalTracking() {
        fullscreenPhysicalOrientationHint = nil
        usedLegacyDeviceOrientationForce = false
        suppressForcedLandscapeArtifactUntil = nil
        guard isTrackingPhysicalOrientationForStatusOverlay else {
            return
        }
        isTrackingPhysicalOrientationForStatusOverlay = false
        stopFullscreenOverlayPhysicalSource()
        unwrapPrintStatusOverlayIfNeeded()
    }

    fileprivate func startFullscreenOverlayPhysicalSource() {
        didReceiveUsableOverlayMotion = false
        didFallbackFromMotionToDeviceOrientation = false
        if shouldUseGravitySourceForOverlay() {
            let manager = overlayMotionManager ?? CMMotionManager()
            overlayMotionManager = manager
            manager.deviceMotionUpdateInterval = 0.2
            manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
                guard let self else {
                    return
                }
                if CameraFullscreenPhysicalOrientation.shouldFallbackToDeviceOrientation(
                    motionError: error != nil,
                    receivedUsableMotion: self.didReceiveUsableOverlayMotion,
                    alreadyFellBack: self.didFallbackFromMotionToDeviceOrientation
                ) {
                    self.fallbackOverlayPhysicalSourceToDeviceOrientationIfNeeded()
                    return
                }
                guard let gravity = motion?.gravity else {
                    return
                }
                self.didReceiveUsableOverlayMotion = true
                self.handleResolvedPhysicalOrientation(
                    CameraFullscreenPhysicalOrientation.orientation(
                        gravityX: gravity.x,
                        gravityY: gravity.y,
                        gravityZ: gravity.z
                    )
                )
            }
            return
        }
        startDeviceOrientationNotificationsForOverlay()
    }

    fileprivate func stopFullscreenOverlayPhysicalSource() {
        overlayMotionManager?.stopDeviceMotionUpdates()
        didReceiveUsableOverlayMotion = false
        if isGeneratingDeviceOrientationNotificationsForOverlay {
            NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
            isGeneratingDeviceOrientationNotificationsForOverlay = false
        }
    }

    fileprivate func startDeviceOrientationNotificationsForOverlay() {
        guard !isGeneratingDeviceOrientationNotificationsForOverlay else {
            return
        }
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        isGeneratingDeviceOrientationNotificationsForOverlay = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(physicalDeviceOrientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }

    fileprivate func fallbackOverlayPhysicalSourceToDeviceOrientationIfNeeded() {
        guard !didFallbackFromMotionToDeviceOrientation else {
            return
        }
        didFallbackFromMotionToDeviceOrientation = true
        overlayMotionManager?.stopDeviceMotionUpdates()
        startDeviceOrientationNotificationsForOverlay()
        handleResolvedPhysicalOrientation(UIDevice.current.orientation)
    }

    fileprivate func shouldUseGravitySourceForOverlay() -> Bool {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            return false
        }
        #if targetEnvironment(simulator)
        let isSimulator = true
        #else
        let isSimulator = false
        #endif
        let manager = overlayMotionManager ?? CMMotionManager()
        overlayMotionManager = manager
        return CameraFullscreenPhysicalOrientation.usesGravitySource(
            userInterfaceIdiom: .pad,
            isDeviceMotionAvailable: manager.isDeviceMotionAvailable,
            isSimulator: isSimulator
        )
    }

    @objc fileprivate func physicalDeviceOrientationDidChange() {
        let current = UIDevice.current.orientation
        if let until = suppressForcedLandscapeArtifactUntil, Date() < until, current == .landscapeLeft {
            return
        }
        suppressForcedLandscapeArtifactUntil = nil
        handleResolvedPhysicalOrientation(current)
    }

    fileprivate func handleResolvedPhysicalOrientation(_ current: UIDeviceOrientation) {
        let resolved = CameraFullscreenStatusOverlay.resolvedPhysicalOrientation(current, lastValid: lastValidPhysicalOrientation)
        guard resolved != lastValidPhysicalOrientation else {
            return
        }
        lastValidPhysicalOrientation = resolved
        updatePrintStatusOverlayPlacement()
    }

    fileprivate func fullscreenInterfaceOrientation() -> UIInterfaceOrientation {
        SceneInterfaceOrientation.current(from: view.window)
    }

    fileprivate func wrapPrintStatusOverlayIfNeeded() {
        guard printStatusOverlayView == nil else {
            return
        }
        guard let timeLabel = printTimeLeftLabel, let toolLabel = tool0ActualLabel, let bedLabel = bedActualLabel else {
            return
        }
        guard let host = timeLabel.superview else {
            return
        }

        printStatusLabelsSuperview = host
        printStatusLabelConstraints = host.constraints.filter { constraint in
            isPrintStatusLabel(constraint.firstItem) || isPrintStatusLabel(constraint.secondItem)
        }

        let overlay = UIView()
        overlay.isUserInteractionEnabled = false
        overlay.backgroundColor = .clear
        overlay.translatesAutoresizingMaskIntoConstraints = true
        overlay.autoresizingMask = []
        // Host on the camera view, not the scroll view, so zoom/content-offset
        // layout cannot reuse a transformed frame.
        view.addSubview(overlay)

        timeLabel.removeFromSuperview()
        toolLabel.removeFromSuperview()
        bedLabel.removeFromSuperview()
        overlay.addSubview(timeLabel)
        overlay.addSubview(toolLabel)
        overlay.addSubview(bedLabel)

        let internalConstraints = [
            timeLabel.topAnchor.constraint(equalTo: overlay.topAnchor),
            timeLabel.trailingAnchor.constraint(equalTo: overlay.trailingAnchor),
            timeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor),
            toolLabel.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 3),
            toolLabel.trailingAnchor.constraint(equalTo: overlay.trailingAnchor),
            toolLabel.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor),
            bedLabel.topAnchor.constraint(equalTo: toolLabel.bottomAnchor, constant: 3),
            bedLabel.trailingAnchor.constraint(equalTo: overlay.trailingAnchor),
            bedLabel.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor),
            bedLabel.bottomAnchor.constraint(equalTo: overlay.bottomAnchor)
        ]
        NSLayoutConstraint.activate(internalConstraints)
        printStatusOverlayInternalConstraints = internalConstraints
        printStatusOverlayView = overlay
        view.bringSubviewToFront(overlay)
    }

    fileprivate func unwrapPrintStatusOverlayIfNeeded() {
        guard let overlay = printStatusOverlayView else {
            return
        }
        overlay.transform = .identity
        NSLayoutConstraint.deactivate(printStatusOverlayInternalConstraints)
        printStatusOverlayInternalConstraints = []

        if let host = printStatusLabelsSuperview {
            for label in [printTimeLeftLabel, tool0ActualLabel, bedActualLabel] {
                label?.removeFromSuperview()
                if let label = label {
                    host.addSubview(label)
                }
            }
            NSLayoutConstraint.activate(printStatusLabelConstraints)
        }
        overlay.removeFromSuperview()
        printStatusOverlayView = nil
        printStatusLabelsSuperview = nil
        printStatusLabelConstraints = []
    }

    fileprivate func updatePrintStatusOverlayPlacement() {
        guard isTrackingPhysicalOrientationForStatusOverlay, let overlay = printStatusOverlayView, let host = overlay.superview else {
            return
        }
        guard !isUpdatingPrintStatusOverlayPlacement else {
            return
        }
        isUpdatingPrintStatusOverlayPlacement = true
        defer { isUpdatingPrintStatusOverlayPlacement = false }

        // Reset transform before measuring so a previous rotation cannot swap
        // fitted size or leave a stale center from the last physical hold.
        overlay.transform = .identity
        let fittedSize = overlay.systemLayoutSizeFitting(
            UIView.layoutFittingCompressedSize,
            withHorizontalFittingPriority: .fittingSizeLevel,
            verticalFittingPriority: .fittingSizeLevel
        )
        let size: CGSize
        if fittedSize.width >= 1 && fittedSize.height >= 1 {
            size = fittedSize
        } else {
            size = printStatusOverlayFallbackSize()
        }
        overlay.bounds = CGRect(origin: .zero, size: size)

        // iPhone keeps the validated landscapeRight-identity mapping.
        // iPad derives identity from the actual scene/interface orientation.
        let placement: CameraFullscreenStatusOverlay.Placement
        if UIDevice.current.userInterfaceIdiom == .pad {
            placement = CameraFullscreenStatusOverlay.placement(
                physicalOrientation: lastValidPhysicalOrientation,
                interfaceOrientation: fullscreenInterfaceOrientation()
            )
        } else {
            placement = CameraFullscreenStatusOverlay.placement(physicalOrientation: lastValidPhysicalOrientation)
        }
        let target = CameraFullscreenStatusOverlay.targetPoint(
            in: host.bounds,
            safeAreaInsets: host.safeAreaInsets,
            corner: placement.corner,
            topInset: 6,
            sideInset: 10
        )
        overlay.center = CameraFullscreenStatusOverlay.overlayCenter(
            size: size,
            targetTopRight: target,
            rotationRadians: placement.rotationRadians
        )
        overlay.transform = CGAffineTransform(rotationAngle: placement.rotationRadians)
    }

    fileprivate func printStatusOverlayFallbackSize() -> CGSize {
        let labels = [printTimeLeftLabel, tool0ActualLabel, bedActualLabel].compactMap { $0 }
        let width = labels.map { $0.intrinsicContentSize.width }.max() ?? 0
        let height = labels.reduce(CGFloat(0)) { partial, label in
            partial + label.intrinsicContentSize.height
        } + CGFloat(max(0, labels.count - 1)) * 3
        return CGSize(width: max(width, 1), height: max(height, 1))
    }

    fileprivate func isPrintStatusLabel(_ item: AnyObject?) -> Bool {
        return item === printTimeLeftLabel || item === tool0ActualLabel || item === bedActualLabel
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
