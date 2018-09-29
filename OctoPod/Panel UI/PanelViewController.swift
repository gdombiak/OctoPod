import UIKit

class PanelViewController: UIViewController, UIPopoverPresentationControllerDelegate, OctoPrintClientDelegate, OctoPrintSettingsDelegate {
    
    private static let CONNECT_CONFIRMATION = "PANEL_CONNECT_CONFIRMATION"

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()

    var printerConnected: Bool?

    @IBOutlet weak var printerSelectButton: UIBarButtonItem!
    @IBOutlet weak var connectButton: UIBarButtonItem!
    @IBOutlet weak var notRefreshingAlertLabel: UILabel!
    
    var camerasViewController: CamerasViewController?
    var subpanelsViewController: SubpanelsViewController?
    
    var screenHeight: CGFloat!
    var printerSubpanelHeightConstraintPortrait: CGFloat!
    var printerSubpanelHeightConstraintLandscape: CGFloat!

    @IBOutlet weak var printerSubpanelHeightConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Keep track of children controllers
        trackChildrenControllers()
        
        // Add a gesture recognizer to camera view so we can handle taps
        camerasViewController?.embeddedCameraTappedCallback = {() in
            self.handleEmbeddedCameraTap()
        }
        
        // Indicate that we want to instruct users that gestures can be used to manipulate image
        // Messages will not be visible after user used these features
        camerasViewController?.infoGesturesAvailable = true

        // Listen to events when app comes back from background
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        // Listen to events coming from OctoPrintClient
        octoprintClient.delegates.append(self)
        
        // Calculate constraint for subpanel
        calculatePrinterSubpanelHeightConstraints()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // Listen to changes to OctoPrint Settings in case the camera orientation has changed
        octoprintClient.octoPrintSettingsDelegates.append(self)
        // Show default printer
        showDefaultPrinter()
        // Enable connect/disconnect button only if app is not locked
        connectButton.isEnabled = !appConfiguration.appLocked()
        // Enable or disable printer select button depending on number of printers configured
        printerSelectButton.isEnabled = printerManager.getPrinters().count > 1
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // Stop listening to changes to OctoPrint Settings
        octoprintClient.remove(octoPrintSettingsDelegate: self)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Connect / Disconnect

    @IBAction func toggleConnection(_ sender: Any) {
        if printerConnected! {
            // Define connect logic that will be reused in 2 places. Variable to prevent copy/paste
            let disconnect = {
                self.octoprintClient.disconnectFromPrinter { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                    if requested {
                        self.subpanelsViewController?.printerSelectedChanged()
                    } else {
                        self.handleConnectionError(error: error, response: response)
                    }
                }
            }
            if appConfiguration.confirmationOnDisconnect() {
                // Prompt for confirmation that we want to disconnect from printer
                showConfirm(message: NSLocalizedString("Confirm disconnect", comment: ""), yes: { (UIAlertAction) -> Void in
                    disconnect()
                }, no: { (UIAlertAction) -> Void in
                    // Do nothing
                })
            } else {
                // Disconnect with no prompt to user
                disconnect()
            }
        } else {
            // Define connect logic that will be reused in 2 places. Variable to prevent copy/paste
            let connect = {
                self.octoprintClient.connectToPrinter { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                    if requested {
                        self.subpanelsViewController?.printerSelectedChanged()
                    } else {
                        self.handleConnectionError(error: error, response: response)
                    }
                }
            }
            let defaults = UserDefaults.standard
            if defaults.bool(forKey: PanelViewController.CONNECT_CONFIRMATION) && !appConfiguration.confirmationOnConnect() {
                // Confirmation was accepted and user does not want to be prompted each time so just connect
                connect()
            } else {
                // Prompt for confirmation so users know that if printing then print will be lost
                showConfirm(message: NSLocalizedString("Confirm connect", comment: ""), yes: { (UIAlertAction) -> Void in
                    // Mark that user accepted. Prompt will not appear again if user does not want a prompt each time (this is default case)
                    defaults.set(true, forKey: PanelViewController.CONNECT_CONFIRMATION)
                    // Connect now
                    connect()
                }, no: { (UIAlertAction) -> Void in
                    // Do nothing
                })
            }
        }
    }
    
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "select_camera_popover", let controller = segue.destination as? SelectDefaultPrinterViewController {
            controller.popoverPresentationController!.delegate = self
            // Refresh based on new default printer
            controller.onCompletion = {
                self.subpanelsViewController?.printerSelectedChanged()
                self.camerasViewController?.printerSelectedChanged()
                self.showDefaultPrinter()
            }
        }
        
        if segue.identifier == "full_camera", let controller = segue.destination as? CameraEmbeddedViewController {
            controller.embedded = false
            controller.cameraURL = camerasViewController?.cameraURL()
            controller.cameraOrientation = camerasViewController?.cameraOrientation()
            
            let uiOrientation = UIApplication.shared.statusBarOrientation
            if uiOrientation != UIInterfaceOrientation.landscapeLeft && uiOrientation != UIInterfaceOrientation.landscapeRight {
                // We are not in landscape mode so change it to landscape
                controller.uiPreviousOrientation = uiOrientation  // Set previous value so we can go back to what it was
                // Rotate UI now
                UIDevice.current.setValue(Int(UIInterfaceOrientation.landscapeRight.rawValue), forKey: "orientation")
            }
        }
    }
    
    // MARK: - Unwind operations

    @IBAction func backFromSetTemperature(_ sender: UIStoryboardSegue) {
        if let controller = sender.source as? SetTargetTempViewController, let text = controller.targetTempField.text, let newTarget: Int = Int(text) {
            switch controller.targetTempScope! {
            case SetTargetTempViewController.TargetScope.bed:
                octoprintClient.bedTargetTemperature(newTarget: newTarget) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                    // TODO Handle error
                }
            case SetTargetTempViewController.TargetScope.tool0:
                octoprintClient.toolTargetTemperature(toolNumber: 0, newTarget: newTarget) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                    // TODO Handle error
                }
            case SetTargetTempViewController.TargetScope.tool1:
                octoprintClient.toolTargetTemperature(toolNumber: 1, newTarget: newTarget) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                    // TODO Handle error
                }
            }
        }
    }

    @IBAction func backFromFailedJobRequest(_ sender: UIStoryboardSegue) {
        if let controller = sender.source as? JobInfoViewController, let jobOperation = controller.requestedJobOperation {
            switch jobOperation {
            case .cancel:
                showAlert(NSLocalizedString("Job", comment: ""), message: NSLocalizedString("Notify failed cancel job", comment: ""))
            case .pause:
                showAlert(NSLocalizedString("Job", comment: ""), message: NSLocalizedString("Notify failed pause job", comment: ""))
            case .resume:
                showAlert(NSLocalizedString("Job", comment: ""), message: NSLocalizedString("Notify failed resume job", comment: ""))
            case .restart:
                showAlert(NSLocalizedString("Job", comment: ""), message: NSLocalizedString("Notify failed restart job", comment: ""))
            case .reprint:
                showAlert(NSLocalizedString("Job", comment: ""), message: NSLocalizedString("Notify failed print job again", comment: ""))
            }
        }
    }

    // MARK: - UIPopoverPresentationControllerDelegate
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }

    // We need to add this so it works on iPhone plus in landscape mode
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }
    
    // MARK: - OctoPrintClientDelegate
    
    // Notification that OctoPrint state has changed. This may include printer status information
    func printerStateUpdated(event: CurrentStateEvent) {
        if let closed = event.closedOrError {
            updateConnectButton(printerConnected: !closed)
        }
        subpanelsViewController?.currentStateUpdated(event: event)
    }

    // Notification sent when websockets got connected
    func websocketConnected() {
        DispatchQueue.main.async {
            self.notRefreshingAlertLabel.isHidden = true
        }
    }

    // Notification sent when websockets got disconnected due to an error (or failed to connect)
    func websocketConnectionFailed(error: Error) {
        DispatchQueue.main.async {
            self.notRefreshingAlertLabel.isHidden = false
        }
    }
    
    // Notification that we are about to connect to OctoPrint server
    func notificationAboutToConnectToServer() {
        // Assume printer is not connected
        updateConnectButton(printerConnected: false)
        DispatchQueue.main.async {
            // Clear any error message
            self.notRefreshingAlertLabel.isHidden = true
        }
    }

    // Notification that HTTP request failed (connection error, authentication error or unexpect http status code)
    func handleConnectionError(error: Error?, response: HTTPURLResponse) {
        if let nsError = error as NSError?, let url = response.url {
            if nsError.code == Int(CFNetworkErrors.cfurlErrorTimedOut.rawValue) && url.host == "octopi.local" {
                self.showAlert(NSLocalizedString("Connection failed", comment: ""), message: NSLocalizedString("Cannot reach 'octopi.local' over mobile network or service is down", comment: ""))
            } else if nsError.code == Int(CFNetworkErrors.cfurlErrorTimedOut.rawValue) {
                self.showAlert(NSLocalizedString("Connection failed", comment: ""), message: NSLocalizedString("Service is down or incorrect port", comment: ""))
            } else if nsError.code == Int(CFNetworkErrors.cfurlErrorCancelled.rawValue) {
                // We ask authentication to be cancelled when when creds are bad
                self.showAlert(NSLocalizedString("Authentication failed", comment: ""), message: NSLocalizedString("Incorrect authentication credentials", comment: ""))
            } else {
                self.showAlert(NSLocalizedString("Connection failed", comment: ""), message: "\(nsError.localizedDescription)")
            }
        } else if response.statusCode == 403 {
            self.showAlert(NSLocalizedString("Authentication failed", comment: ""), message: NSLocalizedString("Incorrect API Key", comment: ""))
        }
    }
    
    // MARK: - OctoPrintSettingsDelegate
    
    func sdSupportChanged(sdSupport: Bool) {
        // Do nothing
    }
    
    func cameraOrientationChanged(newOrientation: UIImage.Orientation) {
        DispatchQueue.main.async {
            self.updateForCameraOrientation(orientation: newOrientation)
        }
    }
    
    // Notification that path to camera hosted by OctoPrint has changed
    func cameraPathChanged(streamUrl: String) {
        camerasViewController?.cameraPathChanged(streamUrl: streamUrl)
    }

    // Notification that a new camera has been added or removed. We rely on MultiCam
    // plugin to be installed on OctoPrint so there is no need to re-enter this information
    // URL to cameras is returned in /api/settings under plugins->multicam
    func camerasChanged(camerasURLs: Array<String>) {
        camerasViewController?.camerasChanged(camerasURLs: camerasURLs)
    }

    // React when device orientation changes
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        if let printer = printerManager.getDefaultPrinter() {
            // Update layout depending on camera orientation
            updateForCameraOrientation(orientation: UIImage.Orientation(rawValue: Int(printer.cameraOrientation))!, devicePortrait: size.height == screenHeight)
        }
    }
    
    // MARK: - Private functions
    
    fileprivate func showDefaultPrinter() {
        if let printer = printerManager.getDefaultPrinter() {
            // Update window title to Camera name
            DispatchQueue.main.async { self.navigationItem.title = printer.name }
            
            // Update layout depending on camera orientation
            DispatchQueue.main.async { self.updateForCameraOrientation(orientation: UIImage.Orientation(rawValue: Int(printer.cameraOrientation))!) }

            // Ask octoprintClient to connect to OctoPrint server
            octoprintClient.connectToServer(printer: printer)
        } else {
            DispatchQueue.main.async { self.notRefreshingAlertLabel.isHidden = true }
            // Assume printer is not connected
            updateConnectButton(printerConnected: false)
            // Ask octoprintClient to disconnect from OctoPrint server
            octoprintClient.disconnectFromServer()
        }
    }
    
    fileprivate func updateConnectButton(printerConnected: Bool) {
        DispatchQueue.main.async {
            if !printerConnected {
                self.printerConnected = false
                self.connectButton.title = NSLocalizedString("Connect", comment: "")
            } else {
                self.printerConnected = true
                self.connectButton.title = NSLocalizedString("Disconnect", comment: "")
            }
        }
    }
    
    fileprivate func updateForCameraOrientation(orientation: UIImage.Orientation, devicePortrait: Bool = UIApplication.shared.statusBarOrientation.isPortrait) {
        if orientation == UIImage.Orientation.left || orientation == UIImage.Orientation.leftMirrored || orientation == UIImage.Orientation.rightMirrored || orientation == UIImage.Orientation.right {
            printerSubpanelHeightConstraint.constant = 280
        } else {
            printerSubpanelHeightConstraint.constant = devicePortrait ? printerSubpanelHeightConstraintPortrait! : printerSubpanelHeightConstraintLandscape!
        }
    }
    
    @objc func handleEmbeddedCameraTap() {
        performSegue(withIdentifier: "full_camera", sender: nil)
    }
    
    @objc func appWillEnterForeground() {
        // Show default printer
        showDefaultPrinter()
    }
    
    // We are using Container Views so this is how we keep a reference to the contained view controllers
    fileprivate func trackChildrenControllers() {
        guard let subpanelsChild = children.first as? SubpanelsViewController else  {
            fatalError("Check storyboard for missing SubpanelsViewController")
        }
        
        guard let camerasChild = children.last as? CamerasViewController else {
            fatalError("Check storyboard for missing CamerasViewController")
        }
        subpanelsViewController = subpanelsChild
        camerasViewController = camerasChild
    }
    
    fileprivate func calculatePrinterSubpanelHeightConstraints() {
        let devicePortrait = UIApplication.shared.statusBarOrientation.isPortrait
        screenHeight = devicePortrait ? UIScreen.main.bounds.height : UIScreen.main.bounds.width
        if screenHeight <= 667 {
            // iPhone * (smaller models)
            printerSubpanelHeightConstraintPortrait = 273
            printerSubpanelHeightConstraintLandscape = 330
        } else if screenHeight == 736 {
            // iPhone 7/8 Plus
            printerSubpanelHeightConstraintPortrait = 313
            printerSubpanelHeightConstraintLandscape = 330
        } else if screenHeight == 812 {
            // iPhone X, Xs
            printerSubpanelHeightConstraintPortrait = 360
            printerSubpanelHeightConstraintLandscape = 330
        } else if screenHeight == 896 {
            // iPhone Xr, Xs Max
            printerSubpanelHeightConstraintPortrait = 413
            printerSubpanelHeightConstraintLandscape = 330
        } else if screenHeight == 1024 {
            // iPad (9.7-inch)
            printerSubpanelHeightConstraintPortrait = 333
            printerSubpanelHeightConstraintLandscape = 300
        } else if screenHeight == 1112 {
            // iPad (10.5-inch)
            printerSubpanelHeightConstraintPortrait = 373
            printerSubpanelHeightConstraintLandscape = 300
        } else if screenHeight >= 1366 {
            // iPad (12.9-inch)
            printerSubpanelHeightConstraintPortrait = 483
            printerSubpanelHeightConstraintLandscape = 300
        } else {
            // Unknown device so use default value
            printerSubpanelHeightConstraintPortrait = 310
            printerSubpanelHeightConstraintLandscape = 330
        }
    }
    
    fileprivate func showAlert(_ title: String, message: String) {
        UIUtils.showAlert(presenter: self, title: title, message: message, done: nil)
    }
    
    fileprivate func showConfirm(message: String, yes: @escaping (UIAlertAction) -> Void, no: @escaping (UIAlertAction) -> Void) {
        UIUtils.showConfirm(presenter: self, message: message, yes: yes, no: no)
    }
}
