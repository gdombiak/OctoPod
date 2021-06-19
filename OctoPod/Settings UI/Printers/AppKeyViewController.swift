import UIKit

class AppKeyViewController: BasePrinterDetailsViewController, UIPopoverPresentationControllerDelegate {

    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()

    /// Application Key that was obtained from OctoPrint after user clicked "Request" button
    var appKey: String?
    var newPrinterPosition: Int16!  // Will have a value only when adding a new printer

    @IBOutlet weak var printerNameField: UITextField!
    @IBOutlet weak var hostnameField: UITextField!
    @IBOutlet weak var urlErrorMessageLabel: UILabel!
    
    @IBOutlet weak var usernameField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    
    @IBOutlet weak var scanInstallationsButton: UIButton!
    
    @IBOutlet weak var includeDashboardLabel: UILabel!
    @IBOutlet weak var includeDashboardSwitch: UISwitch!
    @IBOutlet weak var showCameraLabel: UILabel!
    @IBOutlet weak var showCameraSwitch: UISwitch!

    @IBOutlet weak var requestStatusLabel: UILabel!
    @IBOutlet weak var requestKeyButton: UIButton!
    
    @IBOutlet weak var saveButton: UIBarButtonItem!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        themeLabels()

        // Hide URL error message
        urlErrorMessageLabel.isHidden = true
        requestStatusLabel.text = nil
        // Enable scanning for OctoPrint instances
        scanInstallationsButton.isEnabled = true
        
        updateNextButton()
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 3 && indexPath.row == 0 {
            if let _ = requestStatusLabel.text {
                return UITableView.automaticDimension
            }
            // No message to display so hide the row
            return 0
        }
        return super.tableView(tableView, heightForRowAt: indexPath)
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "goto_scan_installations" {
            segue.destination.popoverPresentationController!.delegate = self
            // Make the popover appear at the middle of the button
            segue.destination.popoverPresentationController!.sourceRect = CGRect(x: 0, y: scanInstallationsButton.frame.size.height/2, width: 0, height: 0)
            // Adjust width of popover based on screen size
            segue.destination.preferredContentSize = CGSize(width: tableView.frame.size.width * 0.80, height: 250)
        }
    }

    // MARK: - IB Events

    @IBAction func fieldChanged(_ sender: Any) {
        updateNextButton()
    }

    @IBAction func urlChanged(_ sender: Any) {
        if let inputURL = hostnameField.text {
            // Add http protocol to URL if no protocol was specified
            if !inputURL.lowercased().starts(with: "http") {
                hostnameField.text = "http://" + inputURL
            }
            // Remove trailing / if present
            if inputURL.hasSuffix("/") {
                hostnameField.text = String(hostnameField.text!.dropLast())
            }
        }
        // Hide or show URL error message
        urlErrorMessageLabel.isHidden = isValidURL()
        // Refresh row height that will handle error message
        tableView.beginUpdates()
        tableView.endUpdates()
        updateNextButton()
    }
    
    @IBAction func requestAppKeyPressed(_ sender: Any) {
        self.displayRequestProgress(message: NSLocalizedString("Contacting OctoPrint.", comment: "")) {
            // Disable request button to prevent multiple requests
            self.requestKeyButton.isEnabled = false
            // Disable changing URL of hostname and reverse proxy user/password while request is pending
            self.hostnameField.isEnabled = false
            self.usernameField.isEnabled = false
            self.passwordField.isEnabled = false
            self.scanInstallationsButton.isEnabled = false
        }
        let restClient = OctoPrintRESTClient()
        restClient.connectToServer(serverURL: hostnameField.text!, apiKey: "", username: usernameField.text, password: passwordField.text)
        restClient.appkeyProbe { (supported: Bool, error: Error?, response: HTTPURLResponse) in
            if supported {
                // Start request for obtaining application key for this OctoPod app
                let deviceType = UIDevice.current.userInterfaceIdiom == .phone ? "iPhone" : "iPad"
                let time = UIUtils.dateToString(date: Date())
                let appIdentifier = "OctoPod \(deviceType) - \(time)"
                restClient.appkeyRequest(app: appIdentifier) { (location: String?, error: Error?, response: HTTPURLResponse) in
                    if let location = location {
                        self.displayRequestProgress(message: NSLocalizedString("Log into OctoPrint to approve access request.", comment: ""), action: nil)
                        self.pollForDecision(restClient: restClient, location: location)
                    } else {
                        // Display that there was an error requesting app key
                        self.displayRequestError(message: NSLocalizedString("Error obtaining Application Key.", comment: ""))
                    }
                }
            } else {
                // Display that OctoPrint instance does not support Application Key
                let message: String
                if response.statusCode == 404 {
                    message = NSLocalizedString("Application Key not enabled in OctoPrint.", comment: "")
                } else if let error = error {
                    message = error.localizedDescription
                } else {
                    message = NSLocalizedString("Error obtaining Application Key.", comment: "")
                }
                self.displayRequestError(message: message)
            }
        }
    }
    
    @IBAction func cancelChanges(_ sender: Any) {
        goBack()
    }
    
    @IBAction func saveChanges(_ sender: Any) {
        // Add new printer (that will become default if it's the first one)
        createPrinter(name: printerNameField.text!, hostname: hostnameField.text!, apiKey: appKey!, username: usernameField.text, password: passwordField.text, position: newPrinterPosition, includeInDashboard: includeDashboardSwitch.isOn, showCamera: showCameraSwitch.isOn)
        goBack()
    }
    
    // MARK: - Unwind operations
    
    @IBAction func backFromDiscoverOctoPrintInstances(_ sender: UIStoryboardSegue) {
        if let controller = sender.source as? ScanInstallationsViewController, let selectedService = controller.selectedOctoPrint {
            // Set name based on discovered OctoPrint instance
            self.printerNameField.text = selectedService.name
            // Update hostname based on discovered information
            self.hostnameField.text = selectedService.hostname
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
    
    // MARK: - Private functions

    fileprivate func pollForDecision(restClient: OctoPrintRESTClient, location: String) {
        // Start polling for user decision
        restClient.appkeyPoll(location: location) { (appKey: String?, retry: Bool, error: Error?, response: HTTPURLResponse) in
            if let appKey = appKey {
                // We are done. User approved and got an app key
                NSLog("Application key obtained: \(appKey)")
                self.appKey = appKey
                DispatchQueue.main.async {
                    self.requestStatusLabel.text = NSLocalizedString("Application Key obtained. Click save to finish.", comment: "")
                    self.requestStatusLabel.textColor = UIColor.green
                    self.tableView.reloadData()
                    // Enable save button (if app is not locked)
                    self.saveButton.isEnabled = !self.appConfiguration.appLocked()
               }
            } else if retry {
                // Keep polling until timeout or user responds. Wait about a second between polls
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    self.pollForDecision(restClient: restClient, location: location)
                }
            } else {
                // We are done. Display that user declined or request timed out
                self.displayRequestError(message: NSLocalizedString("User declined or request timed out.", comment: ""))
            }
        }
    }
    
    fileprivate func updateNextButton() {
        if appConfiguration.appLocked() {
            // Cannot save printer info if app is locked(read-only mode)
            requestKeyButton.isEnabled = false
            return
        }
        if !(printerNameField.text?.isEmpty)! && !(hostnameField.text?.isEmpty)! {
            requestKeyButton.isEnabled = isValidURL()
        } else {
            requestKeyButton.isEnabled = false
        }
    }
    
    fileprivate func isValidURL() -> Bool {
        if let inputURL = hostnameField.text {
            return UIUtils.isValidURL(inputURL: inputURL)
        }
        return false
    }

    fileprivate func themeLabels() {
        // Theme labels
        let theme = Theme.currentTheme()
        let tintColor = theme.tintColor()
        let placeHolderAttributes: [ NSAttributedString.Key : Any ] = [.foregroundColor: theme.placeholderColor()]
        scanInstallationsButton.tintColor = tintColor
        requestKeyButton.tintColor = tintColor
        includeDashboardLabel.textColor = theme.textColor()
        showCameraLabel.textColor = theme.textColor()
        printerNameField.backgroundColor = theme.backgroundColor()
        printerNameField.attributedPlaceholder = NSAttributedString(string: NSLocalizedString("Printer Name (e.g. MK3)", comment: ""), attributes: placeHolderAttributes)
        printerNameField.textColor = theme.textColor()
        hostnameField.backgroundColor = theme.backgroundColor()
        hostnameField.attributedPlaceholder = NSAttributedString(string: NSLocalizedString("Hostname (e.g. http://octopi.local)", comment: ""), attributes: placeHolderAttributes)
        hostnameField.textColor = theme.textColor()
        usernameField.backgroundColor = theme.backgroundColor()
        usernameField.attributedPlaceholder = NSAttributedString(string: NSLocalizedString("Username", comment: ""), attributes: placeHolderAttributes)
        usernameField.textColor = theme.textColor()
        passwordField.backgroundColor = theme.backgroundColor()
        passwordField.attributedPlaceholder = NSAttributedString(string: NSLocalizedString("Password", comment: ""), attributes: placeHolderAttributes)
        passwordField.textColor = theme.textColor()
    }
    
    fileprivate func displayRequestProgress(message: String, action: (() -> Void)?) {
        DispatchQueue.main.async {
            self.requestStatusLabel.text = message
            self.requestStatusLabel.textColor = Theme.currentTheme().textColor()
            self.tableView.reloadData()
            action?()
       }
    }

    fileprivate func displayRequestError(message: String) {
        DispatchQueue.main.async {
            self.requestStatusLabel.text = message
            self.requestStatusLabel.textColor = UIColor.red
            self.tableView.reloadData()
            // Enable request button again in case user wants to retry
            self.requestKeyButton.isEnabled = true
            // Enable changing URL of hostname and reverse proxy user/password
            self.hostnameField.isEnabled = true
            self.usernameField.isEnabled = true
            self.passwordField.isEnabled = true
            self.scanInstallationsButton.isEnabled = true
       }
    }
}
