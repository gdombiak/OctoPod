import UIKit

class PanelViewController: UIViewController, UIPopoverPresentationControllerDelegate, OctoPrintClientDelegate {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()

    var printerConnected: Bool?

    @IBOutlet weak var printerSelectButton: UIBarButtonItem!
    @IBOutlet weak var smallCameraView: UIView!
    @IBOutlet weak var connectButton: UIBarButtonItem!
    @IBOutlet weak var notRefreshingAlertLabel: UILabel!
    
    var printerSubpanelViewController: PrinterSubpanelViewController?
    var cameraEmbeddedViewController: CameraEmbeddedViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Keep track of children controllers
        trackChildrenControllers()
        
        // Add a gesture recognizer to camera view so we can handle taps
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleCameraTap))
        smallCameraView.addGestureRecognizer(tapGesture)

        // Listen to events when app comes back from background
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: Notification.Name.UIApplicationWillEnterForeground, object: nil)
        
        // Listen to events coming from OctoPrintClient
        octoprintClient.delegates.append(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // Show default printer
        showDefaultPrinter()
        // Enable or disable printer select button depending on number of printers configured
        printerSelectButton.isEnabled = printerManager.getPrinters().count > 1
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func toggleConnection(_ sender: Any) {
        if printerConnected! {
            // Prompt for confirmation that we want to disconnect from printer
            showConfirm(message: "Do you want to disconnect from the printer?", yes: { (UIAlertAction) -> Void in
                self.octoprintClient.disconnectFromPrinter { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                    if requested {
                        self.printerSubpanelViewController?.printerSelectedChanged()
                    } else {
                        self.handleConnectionError(error: error, response: response)
                    }
                }
            }, no: { (UIAlertAction) -> Void in
                // Do nothing
            })
        } else {
            octoprintClient.connectToPrinter { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                if requested {
                    self.printerSubpanelViewController?.printerSelectedChanged()
                } else {
                    self.handleConnectionError(error: error, response: response)
                }
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
                self.printerSubpanelViewController?.printerSelectedChanged()
                self.cameraEmbeddedViewController?.printerSelectedChanged()
                self.showDefaultPrinter()
            }
        }
        
        if segue.identifier == "full_camera", let controller = segue.destination as? CameraEmbeddedViewController {
            controller.embedded = false
            
            UIDevice.current.setValue(Int(UIInterfaceOrientation.landscapeRight.rawValue), forKey: "orientation")
        }
    }
    
    // MARK: - Unwind operations

    @IBAction func backFromSetTemperature(_ sender: UIStoryboardSegue) {
        if let controller = sender.source as? SetTargetTempViewController, let text = controller.targetTempField.text {
            let newTarget: Int = Int(text)!
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
                showAlert("Job", message: "Failed to request to cancel print job")
            case .pause:
                showAlert("Job", message: "Failed to request to pause print job")
            case .resume:
                showAlert("Job", message: "Failed to request to resume print job")
            case .restart:
                showAlert("Job", message: "Failed to request to restart print job")
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
        printerSubpanelViewController?.currentStateUpdated(event: event)
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
                self.showAlert("Connection Failed", message: "Cannot reach 'octopi.local' over mobile network or service is down")
            } else if nsError.code == Int(CFNetworkErrors.cfurlErrorTimedOut.rawValue) {
                self.showAlert("Connection Failed", message: "Service is down or incorrect port")
            } else if nsError.code == Int(CFNetworkErrors.cfurlErrorCancelled.rawValue) {
                // We ask authentication to be cancelled when when creds are bad
                self.showAlert("Authentication Failed", message: "Incorrect authentication credentials")
            } else {
                self.showAlert("Connection Failed", message: "\(nsError.localizedDescription)")
            }
        } else if response.statusCode == 403 {
            self.showAlert("Authentication Failed", message: "Incorrect API Key")
        }
    }
    
    // MARK: - Private functions
    
    fileprivate func showDefaultPrinter() {
        if let printer = printerManager.getDefaultPrinter() {
            // Update window title to Camera name
            DispatchQueue.main.async { self.navigationItem.title = printer.name }
            
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
                self.connectButton.title = "Connect"
            } else {
                self.printerConnected = true
                self.connectButton.title = "Disconnect"
            }
        }
    }
    
    @objc func handleCameraTap() {
        performSegue(withIdentifier: "full_camera", sender: nil)
    }
    
    @objc func appWillEnterForeground() {
        // Show default printer
        showDefaultPrinter()
    }
    
    // We are using Container Views so this is how we keep a reference to the contained view controllers
    fileprivate func trackChildrenControllers() {
        guard let printerSubpanel = childViewControllers.first as? PrinterSubpanelViewController else  {
            fatalError("Check storyboard for missing PrinterSubpanelViewController")
        }
        
        guard let cameraChild = childViewControllers.last as? CameraEmbeddedViewController else {
            fatalError("Check storyboard for missing CameraEmbeddedViewController")
        }
        printerSubpanelViewController = printerSubpanel
        cameraEmbeddedViewController = cameraChild
    }
    
    fileprivate func showAlert(_ title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: { (UIAlertAction) -> Void in
            // Nothing to do here
        }))
        // We are not always on the main thread so present dialog on main thread to prevent crashes
        DispatchQueue.main.async {
            self.present(alert, animated: true) { () -> Void in
                // Nothing to do here
            }
        }
    }
    
    fileprivate func showConfirm(message: String, yes: @escaping (UIAlertAction) -> Void, no: @escaping (UIAlertAction) -> Void) {
        let alert = UIAlertController(title: "Confirm", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: yes))
        // Use default style and not cancel style for NO so it appears on the right
        alert.addAction(UIAlertAction(title: "No", style: .default, handler: no))
        self.present(alert, animated: true) { () -> Void in
            // Nothing to do here
        }
    }
}
