import UIKit

class PanelViewController: UIViewController, UIPopoverPresentationControllerDelegate, OctoPrintClientDelegate, OctoPrintSettingsDelegate, AppConfigurationDelegate, CameraViewDelegate, DefaultPrinterManagerDelegate, UITabBarControllerDelegate, SubpanelsVCDelegate {
    
    private static let CONNECT_CONFIRMATION = "PANEL_CONNECT_CONFIRMATION"
    private static let REMINDERS_SHOWN = "PANEL_REMINDERS_SHOWN_3_2"  // Key that stores if we should show reminders about important new things to users. Key might change per version
    private static let TOOLTIP_SWIPE_PRINTERS = "PANEL_TOOLTIP_SWIPE_PRINTERS"

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()
    let defaultPrinterManager: DefaultPrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).defaultPrinterManager }()
    let pluginUpdatesManager: PluginUpdatesManager = { return (UIApplication.shared.delegate as! AppDelegate).pluginUpdatesManager }()

    var printerConnected: Bool?

    @IBOutlet weak var printerSelectButton: UIBarButtonItem!
    @IBOutlet weak var connectButton: UIBarButtonItem!
    @IBOutlet weak var cameraGridButton: UIButton!
    
    @IBOutlet weak var notRefreshingButton: UIButton!
    var notRefreshingReason: String?
    
    var camerasViewController: CamerasViewController?
    var subpanelsViewController: SubpanelsViewController?
    @IBOutlet weak var subpanelsView: UIView!
    
    var screenHeight: CGFloat!
    var imageAspectRatio16_9: Bool = false
    var transitioningNewPage: Bool = false
    var camera4_3HeightConstraintPortrait: CGFloat! = 313
    var camera4_3HeightConstraintLandscape: CGFloat! = 330
    var camera16_9HeightConstraintPortrait: CGFloat! = 313
    var cameral16_9HeightConstraintLandscape: CGFloat! = 330

    var uiOrientationBeforeFullScreen: UIInterfaceOrientation?
    @IBOutlet weak var cameraHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var cameraToSubpanelConstraint: NSLayoutConstraint!
    @IBOutlet weak var cameraToBottomConstraint: NSLayoutConstraint!
    
    /// List of plugin updates that are available. Variable will have value only after we did the check
    var updatesAvailable: Array<PluginUpdatesManager.UpdateAvailable>?
    
    // Gestures to switch between printers
    var swipeLeftGestureRecognizer : UISwipeGestureRecognizer!
    var swipeRightGestureRecognizer : UISwipeGestureRecognizer!
    var swipeDownGestureRecognizer : UISwipeGestureRecognizer!
    var tapGestureRecognizer : UITapGestureRecognizer!
    
    /// Remember if screen turns off when app is idle. This is used when coming back from full screen camera
    var previousIdleTimer = UIApplication.shared.isIdleTimerDisabled

    override func viewDidLoad() {
        super.viewDidLoad()

        // Keep track of children controllers
        trackChildrenControllers()
        
        // Add a gesture recognizer to camera view so we can handle taps
        camerasViewController?.embeddedCameraTappedCallback = {(CameraEmbeddedViewController) in
            self.handleEmbeddedCameraTap()
        }
        
        // Listen to event when first image gets loaded so we can adjust UI based on aspect ratio of image
        camerasViewController?.embeddedCameraDelegate = self
        
        // Indicate that we want to instruct users that gestures can be used to manipulate image
        // Messages will not be visible after user used these features
        camerasViewController?.infoGesturesAvailable = true
        
        // Only offer PIP (if supported by device) from main panel window
        camerasViewController?.offerPIP = true
        
        // Listen to event when user swiped and changed active subpanel
        subpanelsViewController?.subpanelsVCDelegate = self

        // Listen to events when app goes to background and comes back from background
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        // Listen to events coming from OctoPrintClient
        octoprintClient.delegates.append(self)
        
        // Calculate constraint for subpanel
        calculateCameraHeightConstraints()
        
        
        // Use aspect fit so image keeps aspect ratio
        notRefreshingButton.imageView?.contentMode = .scaleAspectFit
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // Listen to changes to OctoPrint Settings in case the camera orientation has changed
        octoprintClient.octoPrintSettingsDelegates.append(self)
        // Listen to changes when app is locked or unlocked
        appConfiguration.delegates.append(self)
        // Listen to changes to default printer
        defaultPrinterManager.delegates.append(self)
        // Listen to tab controller events
        if let tabController = self.tabBarController {
            tabController.delegate = self  // Not ideal solution since we might be overriding other delegates. Good for now
        }
        // Set background color to the view
        let theme = Theme.currentTheme()
        view.backgroundColor = theme.backgroundColor()

        // Show default printer
        showDefaultPrinter()
        // Configure UI based on app locked state
        configureBasedOnAppLockedState()
        // Enable or disable printer select button depending on number of printers configured
        printerSelectButton.isEnabled = printerManager.getPrinters().count > 1
        
        // Add gestures to capture swipes and taps on navigation bar
        addNavBarGestures()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // Stop listening to changes to OctoPrint Settings
        octoprintClient.remove(octoPrintSettingsDelegate: self)
        // Stop listening to changes when app is locked or unlocked
        appConfiguration.remove(appConfigurationDelegate: self)
        // Stop listening to changes to default printer
        defaultPrinterManager.remove(defaultPrinterManagerDelegate: self)
        // Stop listening to tab controller events
        if let tabController = self.tabBarController {
            tabController.delegate = nil
        }
        // Remove gestures that capture swipes and taps on navigation bar
        removeNavBarGestures()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        // Only display reminders and tooltips if at least a printer was configured
        if let _ = printerManager.getDefaultPrinter() {
            let test = false
            if test || !UserDefaults.standard.bool(forKey: PanelViewController.REMINDERS_SHOWN) {
                self.performSegue(withIdentifier: "show_reminders", sender: self)
            } else {
                presentToolTip(tooltipKey: PanelViewController.TOOLTIP_SWIPE_PRINTERS, segueIdentifier: "swipe_printers_tooltip")
            }
            checkDisplayPrintStatusOverCamera()
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Connect / Disconnect

    @IBAction func toggleConnection(_ sender: Any) {
        if printerConnected == nil {
            // Do nothing if we do not know the connection status of the printer
            return
        }
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
    
    // MARK: - Default printer operations
    
    func changeDefaultPrinter(printer: Printer) {
        // Update printer to be the new selected one (i.e. new default)
        defaultPrinterManager.changeToDefaultPrinter(printer: printer, updateWatch: true, connect: false)
        // Refresh UI
        refreshNewSelectedPrinter()
    }
    
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "select_camera_popover", let controller = segue.destination as? SelectDefaultPrinterViewController {
            controller.popoverPresentationController!.delegate = self
            controller.panelViewController = self
        } else if segue.identifier == "printers_dashboard", let controller = segue.destination as? PrintersDashboardViewController {
            controller.panelViewController = self
        } else if segue.identifier == "connection_error_details", let controller = segue.destination as? NotRefreshingReasonViewController {
            controller.popoverPresentationController!.delegate = self
            // Make the popover appear at the middle of the button
            segue.destination.popoverPresentationController!.sourceRect = CGRect(x: notRefreshingButton.frame.size.width/2, y: 0 , width: 0, height: 0)
            if let reason = notRefreshingReason {
                controller.reason = reason
            } else {
                controller.reason = NSLocalizedString("Unknown", comment: "")
            }
        } else if segue.identifier == "show_reminders" {
            segue.destination.popoverPresentationController!.delegate = self
            let width = UIDevice.current.userInterfaceIdiom == .phone ? 320 : 375
            let height = 350
            segue.destination.preferredContentSize = CGSize(width: width, height: height)
            // Center the popover
            segue.destination.popoverPresentationController!.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY,width: 0,height: 0)
        } else if segue.identifier == "updates_available", let controller = segue.destination as? PluginUpdatesViewController {
            controller.popoverPresentationController!.delegate = self
            controller.availableUpdates = updatesAvailable
            if let titleView = navigationController?.view, let height = tabBarController?.tabBar.frame.size.height {
                // Center the popover at the navigation bar height
                controller.popoverPresentationController!.sourceRect = CGRect(x: titleView.bounds.midX, y: height,width: 0,height: 0)
            }
        } else if segue.identifier == "swipe_printers_tooltip" {
            segue.destination.popoverPresentationController!.delegate = self
            // Center the popover at the navigation bar height
            if let titleView = navigationController?.view, let height = tabBarController?.tabBar.frame.size.height {
                // Center the popover at the navigation bar height
                segue.destination.popoverPresentationController!.sourceRect = CGRect(x: titleView.bounds.midX, y: height,width: 0,height: 0)
            }
        }
    }
    
    // MARK: - Unwind operations

    @IBAction func backFromSetTemperature(_ sender: UIStoryboardSegue) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        if let controller = sender.source as? SetTargetTempViewController, let text = controller.targetTempField.text, let newTarget: Int = Int(text) {
            switch controller.targetTempScope! {
            case SetTargetTempViewController.TargetScope.bed:
                octoprintClient.bedTargetTemperature(newTarget: newTarget) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                    if requested {
                        DispatchQueue.main.async {
                            generator.notificationOccurred(.success)
                        }
                    } else {
                        DispatchQueue.main.async {
                            generator.notificationOccurred(.error)
                        }
                        NSLog("Failed to request setting bed's temperature. Response: \(response)")
                    }
                }
                // Donate intent so user can create convenient Siri shortcuts
                if let printer = printerManager.getPrinterByName(name: self.navigationItem.title ?? "_") {
                    IntentsDonations.donateBedTemp(printer: printer, temperature: newTarget)
                }
            case SetTargetTempViewController.TargetScope.tool0:
                octoprintClient.toolTargetTemperature(toolNumber: 0, newTarget: newTarget) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                    if requested {
                        DispatchQueue.main.async {
                            generator.notificationOccurred(.success)
                        }
                    } else {
                        DispatchQueue.main.async {
                            generator.notificationOccurred(.error)
                        }
                        NSLog("Failed to request setting tool0's temperature. Response: \(response)")
                    }
                }
                // Donate intent so user can create convenient Siri shortcuts
                if let printer = printerManager.getPrinterByName(name: self.navigationItem.title ?? "_") {
                    IntentsDonations.donateToolTemp(printer: printer, tool: 0, temperature: newTarget)
                }
            case SetTargetTempViewController.TargetScope.tool1:
                octoprintClient.toolTargetTemperature(toolNumber: 1, newTarget: newTarget) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                    if requested {
                        DispatchQueue.main.async {
                            generator.notificationOccurred(.success)
                        }
                    } else {
                        DispatchQueue.main.async {
                            generator.notificationOccurred(.error)
                        }
                        NSLog("Failed to request setting tool1's temperature. Response: \(response)")
                    }
                }
                // Donate intent so user can create convenient Siri shortcuts
                if let printer = printerManager.getPrinterByName(name: self.navigationItem.title ?? "_") {
                    IntentsDonations.donateToolTemp(printer: printer, tool: 1, temperature: newTarget)
                }
            case SetTargetTempViewController.TargetScope.tool2:
                octoprintClient.toolTargetTemperature(toolNumber: 2, newTarget: newTarget) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                    if requested {
                        DispatchQueue.main.async {
                            generator.notificationOccurred(.success)
                        }
                    } else {
                        DispatchQueue.main.async {
                            generator.notificationOccurred(.error)
                        }
                        NSLog("Failed to request setting tool2's temperature. Response: \(response)")
                    }
                }
                // Donate intent so user can create convenient Siri shortcuts
                if let printer = printerManager.getPrinterByName(name: self.navigationItem.title ?? "_") {
                    IntentsDonations.donateToolTemp(printer: printer, tool: 2, temperature: newTarget)
                }
            case SetTargetTempViewController.TargetScope.tool3:
                octoprintClient.toolTargetTemperature(toolNumber: 3, newTarget: newTarget) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                    if requested {
                        DispatchQueue.main.async {
                            generator.notificationOccurred(.success)
                        }
                    } else {
                        DispatchQueue.main.async {
                            generator.notificationOccurred(.error)
                        }
                        NSLog("Failed to request setting tool3's temperature. Response: \(response)")
                    }
                }
                // Donate intent so user can create convenient Siri shortcuts
                if let printer = printerManager.getPrinterByName(name: self.navigationItem.title ?? "_") {
                    IntentsDonations.donateToolTemp(printer: printer, tool: 3, temperature: newTarget)
                }
            case SetTargetTempViewController.TargetScope.tool4:
                octoprintClient.toolTargetTemperature(toolNumber: 4, newTarget: newTarget) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                    if requested {
                        DispatchQueue.main.async {
                            generator.notificationOccurred(.success)
                        }
                    } else {
                        DispatchQueue.main.async {
                            generator.notificationOccurred(.error)
                        }
                        NSLog("Failed to request setting tool4's temperature. Response: \(response)")
                    }
                }
                // Donate intent so user can create convenient Siri shortcuts
                if let printer = printerManager.getPrinterByName(name: self.navigationItem.title ?? "_") {
                    IntentsDonations.donateToolTemp(printer: printer, tool: 4, temperature: newTarget)
                }
            case SetTargetTempViewController.TargetScope.chamber:
                octoprintClient.chamberTargetTemperature(newTarget: newTarget) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                    if requested {
                        DispatchQueue.main.async {
                            generator.notificationOccurred(.success)
                        }
                    } else {
                        DispatchQueue.main.async {
                            generator.notificationOccurred(.error)
                        }
                        NSLog("Failed to request setting chamber's temperature. Response: \(response)")
                    }
                }
                // Donate intent so user can create convenient Siri shortcuts
                if let printer = printerManager.getPrinterByName(name: self.navigationItem.title ?? "_") {
                    IntentsDonations.donateChamberTemp(printer: printer, temperature: newTarget)
                }
            }
        }
    }

    @IBAction func backFromShowReminders(_ sender: UIStoryboardSegue) {
        UserDefaults.standard.set(true, forKey: PanelViewController.REMINDERS_SHOWN)
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
    
    func printerStateUpdated(event: CurrentStateEvent) {
        if let closed = event.closedOrError {
            updateConnectButton(printerConnected: !closed, assumption: false)
        }
        camerasViewController?.currentStateUpdated(event: event)
        subpanelsViewController?.currentStateUpdated(event: event)
    }

    func websocketConnected() {
        DispatchQueue.main.async {
            self.notRefreshingReason = nil
            self.notRefreshingButton.isHidden = true
        }
    }

    func websocketConnectionFailed(error: Error) {
        DispatchQueue.main.async {
            self.notRefreshingReason = self.obtainConnectionErrorReason(error: error)
            self.notRefreshingButton.isHidden = false
        }
    }
    
    func notificationAboutToConnectToServer() {
        // Assume printer is not connected
        updateConnectButton(printerConnected: false, assumption: true)
        DispatchQueue.main.async {
            // Clear any error message
            self.notRefreshingReason = nil
            self.notRefreshingButton.isHidden = true
        }
    }

    func handleConnectionError(error: Error?, response: HTTPURLResponse) {
        if let nsError = error as NSError?, let url = response.url {
            if let printerHostname = printerManager.getDefaultPrinter()?.hostname, let printerURL = URL(string: printerHostname) {
                if printerURL.host != url.host || printerURL.port != url.port {
                    // Do not show connection error alers of other printers. This might happen when quickly switching between printers
                    return
                }
            }
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
        } else if response.statusCode == 600 {
            self.showAlert(NSLocalizedString("Connection failed", comment: ""), message: NSLocalizedString("Internal OctoEverywhere error", comment: ""))
        } else if response.statusCode == 601 {
            self.showAlert(NSLocalizedString("Connection failed", comment: ""), message: NSLocalizedString("Printer is not connected to OctoEverywhere", comment: ""))
        } else if response.statusCode == 602 {
            self.showAlert(NSLocalizedString("Connection failed", comment: ""), message: NSLocalizedString("OctoEverywhere's connection to OctoPrint timed out", comment: ""))
        } else if response.statusCode == 603 || response.statusCode == 604 {
            self.showAlert(NSLocalizedString("Connection failed", comment: ""), message: NSLocalizedString("Recreate printer in OctoEverywhere and OctoPod", comment: ""))
        } else if response.statusCode == 605 {
            self.showAlert(NSLocalizedString("Connection failed", comment: ""), message: NSLocalizedString("Account is no longer an OctoEverywhere supporter", comment: ""))
        }
    }
    
    func tempHistoryChanged() {
        subpanelsViewController?.tempHistoryChanged()
    }
    
    // MARK: - OctoPrintSettingsDelegate
    
    func cameraOrientationChanged(newOrientation: UIImage.Orientation) {
        DispatchQueue.main.async {
            self.updateForCameraOrientation(orientation: newOrientation)
        }
    }
    
    func cameraPathChanged(streamUrl: String) {
        camerasViewController?.cameraPathChanged(streamUrl: streamUrl)
    }

    func camerasChanged(camerasURLs: Array<String>) {
        camerasViewController?.camerasChanged(camerasURLs: camerasURLs)
    }

    // MARK: - Orientation change

    // React when device orientation changes
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        if subpanelsView != nil && subpanelsView.isHidden {
            // Do nothing if camera is in full screen
            return
        }
        if let printer = printerManager.getDefaultPrinter() {
            // Update layout depending on camera orientation
            updateForCameraOrientation(orientation: UIImage.Orientation(rawValue: Int(printer.cameraOrientation))!, devicePortrait: size.height == screenHeight)
            // Hide/show camera grid button based on orientation
            self.cameraGridButton.isHidden = !self.showCameraGridButton()
            // Add some delay before calculating if we should render temp info
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.checkDisplayPrintStatusOverCamera()
            }
        }
    }
    
    // MARK: - AppConfigurationDelegate
    
    func appLockChanged(locked: Bool) {
        DispatchQueue.main.async {
            self.configureBasedOnAppLockedState()
        }
    }
    
    // MARK: - EmbeddedCameraDelegate
    
    func imageAspectRatio(cameraIndex: Int, ratio: CGFloat) {
        let newRatio = ratio < 0.60
        if imageAspectRatio16_9 != newRatio {
            imageAspectRatio16_9 = newRatio
            if !transitioningNewPage {
                if let printer = printerManager.getDefaultPrinter() {
                    // Check if we need to update printer to remember aspect ratio of first camera
                    if cameraIndex == 0 && imageAspectRatio16_9 != printer.firstCameraAspectRatio16_9 {
                        let newObjectContext = printerManager.newPrivateContext()
                        let printerToUpdate = newObjectContext.object(with: printer.objectID) as! Printer
                        // Update aspect ratio of first camera
                        printerToUpdate.firstCameraAspectRatio16_9 = imageAspectRatio16_9
                        // Persist updated printer
                        printerManager.updatePrinter(printerToUpdate, context: newObjectContext)
                    }
                    let orientation = UIImage.Orientation(rawValue: Int(printer.cameraOrientation))!
                    // Add a tiny delay so the UI does not go crazy
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.updateForCameraOrientation(orientation: orientation)
                    }
                }
            }
        }
    }
    
    func startTransitionNewPage() {
        transitioningNewPage = true
    }
    
    func finishedTransitionNewPage() {
        transitioningNewPage = false
        if let printer = printerManager.getDefaultPrinter() {
            let orientation = UIImage.Orientation(rawValue: Int(printer.cameraOrientation))!
            // Add a tiny delay so the UI does not go crazy
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if self.subpanelsView != nil && self.subpanelsView.isHidden {
                    // Do nothing if camera is in full screen
                    return
                }
                self.updateForCameraOrientation(orientation: orientation)
            }
            self.checkDisplayPrintStatusOverCamera()
        }
    }
    
    // MARK: - SubpanelsVCDelegate
    
    func finishedTransitionSubpanel(index: Int) {
        checkDisplayPrintStatusOverCamera()
    }
    
    func toolLabelVisibilityChanged() {
        checkDisplayPrintStatusOverCamera()
    }
    
    // MARK: - DefaultPrinterManagerDelegate
    
    func defaultPrinterChanged() {
        self.refreshNewSelectedPrinter()
    }
    
    // MARK: - UITabBarControllerDelegate
    
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        // If selected panel is this window then render first subpanel
        if tabBarController.selectedIndex == 0 {
            subpanelsViewController?.renderFirstVC()
            checkDisplayPrintStatusOverCamera()
        }
    }
    
    // MARK: - Private - Navigation Bar Gestures

    fileprivate func addNavBarGestures() {
        // Add gesture when we swipe from right to left
        swipeLeftGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(navigationBarSwiped(_:)))
        swipeLeftGestureRecognizer.direction = .left
        navigationController?.navigationBar.addGestureRecognizer(swipeLeftGestureRecognizer)
        swipeLeftGestureRecognizer.cancelsTouchesInView = false
        
        // Add gesture when we swipe from left to right
        swipeRightGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(navigationBarSwiped(_:)))
        swipeRightGestureRecognizer.direction = .right
        navigationController?.navigationBar.addGestureRecognizer(swipeRightGestureRecognizer)
        swipeRightGestureRecognizer.cancelsTouchesInView = false
        
        // Add gesture when we swipe down
        swipeDownGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(navigationBarSwipedDown(_:)))
        swipeDownGestureRecognizer.direction = .down
        navigationController?.navigationBar.addGestureRecognizer(swipeDownGestureRecognizer)
        swipeDownGestureRecognizer.cancelsTouchesInView = false

        // Add gesture when we tap on nav bar
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(navigationBarTapped(_:)))
        tapGestureRecognizer.numberOfTapsRequired = 1
        tapGestureRecognizer.numberOfTouchesRequired = 1
        navigationController?.navigationBar.addGestureRecognizer(tapGestureRecognizer)
        tapGestureRecognizer.cancelsTouchesInView = false
    }

    fileprivate func removeNavBarGestures() {
        // Remove gesture when we swipe from right to left
        navigationController?.navigationBar.removeGestureRecognizer(swipeLeftGestureRecognizer)
        
        // Remove gesture when we swipe from left to right
        navigationController?.navigationBar.removeGestureRecognizer(swipeRightGestureRecognizer)

        // Remove gesture when we swipe down
        navigationController?.navigationBar.removeGestureRecognizer(swipeDownGestureRecognizer)

        // Remove gesture when we tap on nav bar
        navigationController?.navigationBar.removeGestureRecognizer(tapGestureRecognizer)
    }

    @objc fileprivate func navigationBarSwiped(_ gesture: UIGestureRecognizer) {
        // Change default printer
        let direction: DefaultPrinterManager.SwipeDirection = gesture == swipeLeftGestureRecognizer ? .left : .right
        defaultPrinterManager.navigationBarSwiped(direction: direction)
    }
    
    @objc fileprivate func navigationBarSwipedDown(_ gesture: UIGestureRecognizer) {
        if let printer = printerManager.getDefaultPrinter() {
            // Ignore last time we checked for updates. Force a new check again
            printer.pluginsUpdateNextCheck = nil
            // Check for updates of plugins or OctoPrint itself
            checkUpdatesFor(printer)
        }
    }
    
    @objc fileprivate func navigationBarTapped(_ gesture: UIGestureRecognizer) {
        // Make sure that a button is not tapped.
        let location = gesture.location(in: self.navigationController?.navigationBar)
        let hitView = self.navigationController?.navigationBar.hitTest(location, with: nil)

        guard !(hitView is UIControl) else { return }

        // User clicked on title so open dashboard
        self.performSegue(withIdentifier: "printers_dashboard", sender: self)
    }
    
    // MARK: - Private functions
    
    /// Runs on **main thread**. Enables or disables display of print status overlaid on top of camera view
    fileprivate func checkDisplayPrintStatusOverCamera() {
        if subpanelsView == nil {
            // Do nothing if for whatever reason subpanelsView is nil.
            return
        }
        let printerSubpanelViewController = subpanelsViewController?.currentSubpanelViewController() as? PrinterSubpanelViewController
        camerasViewController?.displayPrintStatus(enabled: subpanelsView.isHidden || printerSubpanelViewController == nil || !printerSubpanelViewController!.tempLabelVisible())
    }
    
    /// Check for plugin updates for specified printer. Printer#pluginsUpdateNextCheck defines when next check is going to happen
    fileprivate func checkUpdatesFor(_ printer: Printer) {
        updatesAvailable = nil
        pluginUpdatesManager.checkUpdatesFor(printer: printer) { (error: Error?, response: HTTPURLResponse, updatesAvailable: Array<PluginUpdatesManager.UpdateAvailable>?) in
            if let updates = updatesAvailable {
                if updates.isEmpty {
                    // No updates found
                    return
                }
                self.updatesAvailable = updates
                // Redirect user to new popover that shows available updates
                DispatchQueue.main.async {
                    self.performSegue(withIdentifier: "updates_available", sender: self)
                }
            } else if response.statusCode == 200 {
                NSLog("User elected to ignore available plugin updates")
            } else if response.statusCode == 304 {
                NSLog("Skipped checking for plugin updates")
            } else {
                NSLog("Unkown case checking for plugin updates. Response: \(response)")
            }
        }
    }
    
    fileprivate func showDefaultPrinter() {
        if let printer = printerManager.getDefaultPrinter() {
            // Update window title to Camera name
            DispatchQueue.main.async {
                self.navigationItem.title = printer.name
                if let navigationController = self.navigationController as? NavigationController {
                    navigationController.refreshForPrinterColors(color: printer.color)
                }
                // Show camera grid button only if printer has many cameras
                self.cameraGridButton.isHidden = !self.showCameraGridButton()
            }
            
            // Use last known aspect ratio of first camera of this printer
            // End user will have a better experience with this
            self.imageAspectRatio16_9 = printer.firstCameraAspectRatio16_9
            
            // Update layout depending on camera orientation
            DispatchQueue.main.async { self.updateForCameraOrientation(orientation: UIImage.Orientation(rawValue: Int(printer.cameraOrientation))!) }

            // Ask octoprintClient to connect to OctoPrint server
            octoprintClient.connectToServer(printer: printer)
            
            // Check for plugin updates
            checkUpdatesFor(printer)
        } else {
            DispatchQueue.main.async {
                self.notRefreshingReason = nil
                self.notRefreshingButton.isHidden = true
                self.cameraGridButton.isHidden = true
            }
            // Assume printer is not connected
            updateConnectButton(printerConnected: false, assumption: true)
            // Ask octoprintClient to disconnect from OctoPrint server
            octoprintClient.disconnectFromServer()
        }
    }
    
    fileprivate func showCameraGridButton() -> Bool {
        // Show camera grid button only if printer has many cameras
        if let printer = printerManager.getDefaultPrinter(), let cameras = printer.getMultiCameras(), cameras.count > 1 && !printer.hideCamera {
            // Hide button when in landscape. Always show when using iPad
            return !UIDevice.current.orientation.isLandscape || UIDevice.current.userInterfaceIdiom == .pad
        }
        return false
    }
    
    fileprivate func refreshNewSelectedPrinter() {
        // Connect to new selected printer and update main page
        self.showDefaultPrinter()
        // Update subviews (now that we are connected to new printer)
        self.subpanelsViewController?.printerSelectedChanged()
        self.camerasViewController?.printerSelectedChanged()
    }

    fileprivate func updateConnectButton(printerConnected: Bool, assumption: Bool) {
        DispatchQueue.main.async {
            if !printerConnected {
                self.printerConnected = false
                self.connectButton.title = NSLocalizedString("Connect", comment: "")
            } else {
                self.printerConnected = true
                self.connectButton.title = NSLocalizedString("Disconnect", comment: "")
            }
            // Only enable button if we are sure about connection state
            self.connectButton.isEnabled = !assumption && !self.appConfiguration.appLocked()
        }
    }
    
    fileprivate func updateForCameraOrientation(orientation: UIImage.Orientation, devicePortrait: Bool = UIApplication.shared.statusBarOrientation.isPortrait) {
        if cameraHeightConstraint == nil {
            // Do nothing if for some reason the weak var cameraHeightConstraint is no longer there. Will fix a reported crash but not sure if it will crash later
            return
        }
        // Check if user decided to hide camera subpanel for this printer 
        if let printer = printerManager.getDefaultPrinter(), printer.hideCamera {
            cameraHeightConstraint.constant = 0
            return
        }
        if orientation == UIImage.Orientation.left || orientation == UIImage.Orientation.leftMirrored || orientation == UIImage.Orientation.rightMirrored || orientation == UIImage.Orientation.right {
            cameraHeightConstraint.constant = 281 + 50
        } else {
            if imageAspectRatio16_9 {
                cameraHeightConstraint.constant = devicePortrait ? camera16_9HeightConstraintPortrait! : cameral16_9HeightConstraintLandscape!
            } else {
                cameraHeightConstraint.constant = devicePortrait ? camera4_3HeightConstraintPortrait! : camera4_3HeightConstraintLandscape!
            }
        }
    }
    
    @objc func handleEmbeddedCameraTap() {
        if !subpanelsView.isHidden {
            // Hide the navigation bar on this view controller
            self.navigationController?.setNavigationBarHidden(true, animated: false)
            // Hide tab bar (located at the bottom)
            self.tabBarController?.tabBar.isHidden = true
            // Hide bottom panel
            subpanelsView.isHidden = true
            // Hide camera grid button
            cameraGridButton.isHidden = true
            // Switch constraints priority. Height does not matter now. Bottom constraint matters with 0 to safe view
            cameraHeightConstraint.priority = UILayoutPriority(rawValue: 998)       // Ignore height of camera view
            cameraToSubpanelConstraint.priority = UILayoutPriority(rawValue: 998)   // Ignore relationship to subpanel
            cameraToBottomConstraint.priority = UILayoutPriority(rawValue: 999)     // Activate distance to bottom of screen

            // Flip orientation if needed
            let uiOrientation = UIApplication.shared.statusBarOrientation
            if uiOrientation != UIInterfaceOrientation.landscapeLeft && uiOrientation != UIInterfaceOrientation.landscapeRight {
                // We are not in landscape mode so change it to landscape
                uiOrientationBeforeFullScreen = uiOrientation  // Set previous value so we can go back to what it was
                // Rotate UI now
                UIDevice.current.setValue(Int(UIInterfaceOrientation.landscapeRight.rawValue), forKey: "orientation")
            } else {
                uiOrientationBeforeFullScreen = nil
            }
            // Turn off idle timer that turns off display when app is idle. Full screen camera will prevent device from turning screen off
            previousIdleTimer = UIApplication.shared.isIdleTimerDisabled
            UIApplication.shared.isIdleTimerDisabled = true
        } else {
            // Show the navigation bar on this view controller
            self.navigationController?.setNavigationBarHidden(false, animated: false)
            // Show tab bar (located at the bottom)
            self.tabBarController?.tabBar.isHidden = false
            // Show bottom panel
            subpanelsView.isHidden = false
            // Show camera grid button only if printer has many cameras
            cameraGridButton.isHidden = !showCameraGridButton()
            // Switch constraints priority. Height matters again. Bottom constraint no longer matters
            cameraHeightConstraint.priority = UILayoutPriority(rawValue: 999)      // Activate height of camera view
            cameraToSubpanelConstraint.priority = UILayoutPriority(rawValue: 999)  // Activate relationship to subpanel
            cameraToBottomConstraint.priority = UILayoutPriority(rawValue: 998)    // Ignore distance to bottom of screen
            // Flip orientation if needed
            if let orientation = uiOrientationBeforeFullScreen {
                // When running full screen we are forcing landscape so we go back to portrait when leaving
                UIDevice.current.setValue(Int(orientation.rawValue), forKey: "orientation")
                uiOrientationBeforeFullScreen = nil
            }
            // Restore idle timer to previous value before going full screen
            UIApplication.shared.isIdleTimerDisabled = previousIdleTimer
        }
        // Add some delay before calculating if we should render temp info
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.checkDisplayPrintStatusOverCamera()
        }
    }
    
    @objc func appWillEnterForeground() {
        // Show default printer
        showDefaultPrinter()
    }
    
    @objc func appDidEnterBackground() {
        // Close websocket connection to stop network traffic
        octoprintClient.disconnectFromServer()
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
    
    fileprivate func configureBasedOnAppLockedState() {
        // Enable connect/disconnect button only if app is not locked
        connectButton.isEnabled = !appConfiguration.appLocked()
    }

    fileprivate func calculateCameraHeightConstraints() {
        let devicePortrait = UIApplication.shared.statusBarOrientation.isPortrait
        screenHeight = devicePortrait ? UIScreen.main.bounds.height : UIScreen.main.bounds.width
        let constraints = UIUtils.calculateCameraHeightConstraints(screenHeight: screenHeight)
        
        camera4_3HeightConstraintPortrait = constraints.cameraHeight4_3ConstraintPortrait
        camera4_3HeightConstraintLandscape = constraints.cameraHeight4_3ConstraintLandscape
        camera16_9HeightConstraintPortrait = constraints.camera16_9HeightConstraintPortrait
        cameral16_9HeightConstraintLandscape = constraints.cameral16_9HeightConstraintLandscape
    }
    
    fileprivate func obtainConnectionErrorReason(error: Error) -> String {
        if let nsError = error as NSError? {
            if nsError.code >= -9851 && nsError.code <= -9800 {
                // Some problem with SSL or the certificate
                return NSLocalizedString("Bad Certificate or SSL Problem", comment: "HTTPS failed for some reason. Could be bad certs, hostname does not match, cert expired, etc.")
            } else if nsError.domain == "kCFErrorDomainCFNetwork" && nsError.code == 2 {
                return NSLocalizedString("Server cannot be found", comment: "DNS resolution failed. Cannot resolve hostname")
            } else if nsError.domain == "NSPOSIXErrorDomain" && nsError.code == 61 {
                return NSLocalizedString("Could not connect to the server", comment: "Connection to server failed")
            }
        }
        return error.localizedDescription
    }
    
    fileprivate func presentToolTip(tooltipKey: String, segueIdentifier: String) {
        let tooltipShown = UserDefaults.standard.bool(forKey: tooltipKey)
        let viewShown = view.window != nil
        if viewShown && !tooltipShown && self.presentedViewController == nil {
            UserDefaults.standard.set(true, forKey: tooltipKey)
            self.performSegue(withIdentifier: segueIdentifier, sender: self)
        }
    }
    
    fileprivate func showAlert(_ title: String, message: String) {
        UIUtils.showAlert(presenter: self, title: title, message: message, done: nil)
    }
    
    fileprivate func showConfirm(message: String, yes: @escaping (UIAlertAction) -> Void, no: @escaping (UIAlertAction) -> Void) {
        UIUtils.showConfirm(presenter: self, message: message, yes: yes, no: no)
    }
}
