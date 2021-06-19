import UIKit

class PrinterDetailsViewController: BasePrinterDetailsViewController, CloudKitPrinterDelegate, UIPopoverPresentationControllerDelegate {
    
    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()

    var updatePrinter: Printer? = nil
    var scannedKey: String?
    var newPrinterPosition: Int16!  // Will have a value only when adding a new printer

    @IBOutlet weak var printerNameField: UITextField!
    @IBOutlet weak var hostnameField: UITextField!
    @IBOutlet weak var urlErrorMessageLabel: UILabel!
    @IBOutlet weak var apiKeyField: UITextField!
    
    @IBOutlet weak var usernameField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    
    @IBOutlet weak var scanInstallationsButton: UIButton!
    @IBOutlet weak var scanAPIKeyButton: UIButton!
    
    @IBOutlet weak var includeDashboardLabel: UILabel!
    @IBOutlet weak var includeDashboardSwitch: UISwitch!
    @IBOutlet weak var showCameraLabel: UILabel!
    @IBOutlet weak var showCameraSwitch: UISwitch!

    @IBOutlet weak var saveButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        themeLabels()

        if let selectedPrinter = updatePrinter {
            updateFieldsForPrinter(printer: selectedPrinter)
            // Disable scanning for OctoPrint instances
            scanInstallationsButton.isEnabled = false
        } else {
            // Hide URL error message
            urlErrorMessageLabel.isHidden = true
            // Enable scanning for OctoPrint instances
            scanInstallationsButton.isEnabled = true
        }

        // Register for keyboard notifications
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)

        // Listen to events when printers get updated from iCloud information
        cloudKitPrinterManager.delegates.append(self)
    }

    override func viewWillDisappear(_ animated: Bool) {
        // Unregister for keyboard notifications
        NotificationCenter.default.removeObserver(self)

        // Stop listening to events when printers get updated from iCloud information
        cloudKitPrinterManager.remove(cloudKitPrinterDelegate: self)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func cancelChanges(_ sender: Any) {
        goBack()
    }
    
    @IBAction func saveChanges(_ sender: Any) {
        if let printer = updatePrinter {
            updatePrinter(printer: printer, name: printerNameField.text!, hostname: hostnameField.text!, apiKey: apiKeyField.text!, username: usernameField.text, password: passwordField.text, includeInDashboard: includeDashboardSwitch.isOn, showCamera: showCameraSwitch.isOn)
        } else {
            // Add new printer (that will become default if it's the first one)
            createPrinter(name: printerNameField.text!, hostname: hostnameField.text!, apiKey: apiKeyField.text!, username: usernameField.text, password: passwordField.text, position: newPrinterPosition, includeInDashboard: includeDashboardSwitch.isOn, showCamera: showCameraSwitch.isOn)
        }
        goBack()
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
        updateSaveButton()
    }
    
    @IBAction func fieldChanged(_ sender: Any) {
        updateSaveButton()
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            if indexPath.row == 1 && !urlErrorMessageLabel.isHidden {
                // Show higher row height so we can display error message
                return 70
            }
        }
        return 44
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
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "goto_scan_installations" {
            segue.destination.popoverPresentationController!.delegate = self
            // Make the popover appear at the middle of the button
            segue.destination.popoverPresentationController!.sourceRect = CGRect(x: 0, y: scanInstallationsButton.frame.size.height/2, width: 0, height: 0)
            // Adjust width of popover based on screen size
            segue.destination.preferredContentSize = CGSize(width: tableView.frame.size.width * 0.80, height: 250)
        }
    }
 
    @IBAction func unwindScanQRCode(_ sender: UIStoryboardSegue) {
        if let scanner = sender.source as? ScannerViewController {
            self.apiKeyField.text = scanner.scannedQRCode
            scannedKey = scanner.scannedQRCode
            self.updateSaveButton()
        }
    }

    // MARK: - CloudKitPrinterDelegate
    
    func printersUpdated() {
        // Do nothing. We care about individual printers
    }

    func printerAdded(printer: Printer) {
        // Do nothing. We care about the printer we are editing only
    }
    
    func printerUpdated(printer: Printer) {
        if printer == updatePrinter {
            // Same printer we are editing so update page with latest info
            DispatchQueue.main.async {
                self.updateFieldsForPrinter(printer: printer)
            }
        }
    }
    
    func printerDeleted(printer: Printer) {
        if printer == updatePrinter {
            // Same printer we are editing so close window
            DispatchQueue.main.async {
                self.goBack()
            }
        }
    }

    func iCloudStatusChanged(connected: Bool) {
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

    fileprivate func updateFieldsForPrinter(printer: Printer) {
        printerNameField.text = printer.name
        hostnameField.text = printer.hostname
        // Hide or show URL error message
        urlErrorMessageLabel.isHidden = isValidURL()
        apiKeyField.text = scannedKey == nil ? printer.apiKey : scannedKey
        usernameField.text = printer.username
        passwordField.text = printer.password
        includeDashboardSwitch.isOn = printer.includeInDashboard
        showCameraSwitch.isOn = !printer.hideCamera
    }
    
    fileprivate func updateSaveButton() {
        if appConfiguration.appLocked() {
            // Cannot save printer info if app is locked(read-only mode)
            saveButton.isEnabled = false
            return
        }
        if !(printerNameField.text?.isEmpty)! && !(hostnameField.text?.isEmpty)! && !(apiKeyField.text?.isEmpty)! {
            saveButton.isEnabled = isValidURL()
        } else {
            saveButton.isEnabled = false
        }
    }
    
    fileprivate func isValidURL() -> Bool {
        if let inputURL = hostnameField.text {
            return UIUtils.isValidURL(inputURL: inputURL)
        }
        return false
    }

    fileprivate func adjustingHeight(show: Bool, notification: Notification) {
        let userInfo = notification.userInfo!
        let keyboardFrame: CGRect = (userInfo[UIResponder.keyboardFrameBeginUserInfoKey] as! NSValue).cgRectValue
        //        let animationDurarion = userInfo[UIKeyboardAnimationDurationUserInfoKey] as! TimeInterval
        let changeInHeight = (keyboardFrame.height + 40) * (show ? 1 : -1)
        // Set the table content inset to the keyboard height
        tableView.contentInset.bottom = changeInHeight
    }
    
    fileprivate func themeLabels() {
        // Theme labels
        let theme = Theme.currentTheme()
        let tintColor = theme.tintColor()
        let placeHolderAttributes: [ NSAttributedString.Key : Any ] = [.foregroundColor: theme.placeholderColor()]
        scanAPIKeyButton.tintColor = tintColor
        scanInstallationsButton.tintColor = tintColor
        includeDashboardLabel.textColor = theme.textColor()
        showCameraLabel.textColor = theme.textColor()
        printerNameField.backgroundColor = theme.backgroundColor()
        printerNameField.attributedPlaceholder = NSAttributedString(string: NSLocalizedString("Printer Name (e.g. MK3)", comment: ""), attributes: placeHolderAttributes)
        printerNameField.textColor = theme.textColor()
        hostnameField.backgroundColor = theme.backgroundColor()
        hostnameField.attributedPlaceholder = NSAttributedString(string: NSLocalizedString("Hostname (e.g. http://octopi.local)", comment: ""), attributes: placeHolderAttributes)
        hostnameField.textColor = theme.textColor()
        apiKeyField.backgroundColor = theme.backgroundColor()
        apiKeyField.attributedPlaceholder = NSAttributedString(string: NSLocalizedString("API Key", comment: ""), attributes: placeHolderAttributes)
        apiKeyField.textColor = theme.textColor()
        usernameField.backgroundColor = theme.backgroundColor()
        usernameField.attributedPlaceholder = NSAttributedString(string: NSLocalizedString("Username", comment: ""), attributes: placeHolderAttributes)
        usernameField.textColor = theme.textColor()
        passwordField.backgroundColor = theme.backgroundColor()
        passwordField.attributedPlaceholder = NSAttributedString(string: NSLocalizedString("Password", comment: ""), attributes: placeHolderAttributes)
        passwordField.textColor = theme.textColor()
    }
    
    @objc func keyboardWillShow(notification: Notification) {
        adjustingHeight(show: true, notification: notification)
    }
    
    @objc func keyboardWillHide(notification: Notification) {
        adjustingHeight(show: false, notification: notification)
    }    
}
