import UIKit

class PrinterDetailsViewController: ThemedStaticUITableViewController, CloudKitPrinterDelegate {
    
    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let cloudKitPrinterManager: CloudKitPrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).cloudKitPrinterManager }()

    var updatePrinter: Printer? = nil
    var scannedKey: String?

    @IBOutlet weak var printerNameField: UITextField!
    @IBOutlet weak var hostnameField: UITextField!
    @IBOutlet weak var urlErrorMessageLabel: UILabel!
    @IBOutlet weak var apiKeyField: UITextField!
    
    @IBOutlet weak var usernameField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    
    @IBOutlet weak var saveButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let selectedPrinter = updatePrinter {
            updateFieldsForPrinter(printer: selectedPrinter)
        } else {
            // Hide URL error message
            urlErrorMessageLabel.isHidden = true
        }

        // Register for keyboard notifications
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: .UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: .UIKeyboardWillHide, object: nil)

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
            // Update existing printer
            printer.name = printerNameField.text!
            printer.hostname = hostnameField.text!
            printer.apiKey = apiKeyField.text!
            printer.userModified = Date() // Track when settings were modified
            
            printer.username = usernameField.text
            printer.password = passwordField.text
            
            // Mark that iCloud needs to be updated
            printer.iCloudUpdate = true
            
            printerManager.updatePrinter(printer)
        } else {
            // Add new printer (that will become default if it's the first one)
            let _ = printerManager.addPrinter(name: printerNameField.text!, hostname: hostnameField.text!, apiKey: apiKeyField.text!, username: usernameField.text, password: passwordField.text, iCloudUpdate: true)
        }
        
        // Push changes to iCloud so other devices of the user get updated (only if iCloud enabled and user is logged in)
        cloudKitPrinterManager.pushChanges(completion: nil)
        
        goBack()
    }
    
    @IBAction func urlChanged(_ sender: Any) {
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
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
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

    // MARK: - Private functions

    fileprivate func updateFieldsForPrinter(printer: Printer) {
        printerNameField.text = printer.name
        hostnameField.text = printer.hostname
        // Hide or show URL error message
        urlErrorMessageLabel.isHidden = isValidURL()
        apiKeyField.text = scannedKey == nil ? printer.apiKey : scannedKey
        usernameField.text = printer.username
        passwordField.text = printer.password
    }
    
    fileprivate func updateSaveButton() {
        if !(printerNameField.text?.isEmpty)! && !(hostnameField.text?.isEmpty)! && !(apiKeyField.text?.isEmpty)! {
            saveButton.isEnabled = isValidURL()
        } else {
            saveButton.isEnabled = false
        }
    }
    
    fileprivate func goBack() {
        // Go back to previous page and execute the unwinsScanQRCode IBAction
        performSegue(withIdentifier: "unwindPrintersUpdated", sender: self)
    }
    
    fileprivate func isValidURL() -> Bool {
        if let inputURL = hostnameField.text {
            let urlRegEx = "(http|https)://((\\w)*|([0-9]*)|([-|_])*)+([\\.|/]((\\w)*|([0-9]*)|([-|_])*))+(:[0-9]+)?"
            let urlTest = NSPredicate(format: "SELF MATCHES %@", urlRegEx)
            var result = urlTest.evaluate(with: inputURL)
            if !result {
                let ipv6RegEx = "(http|https)://(\\[)?(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))(])?(:[0-9]+)?"
                let ipv6Test = NSPredicate(format: "SELF MATCHES %@", ipv6RegEx)
                result = ipv6Test.evaluate(with: inputURL)
            }
            return result
        }
        return false
    }

    fileprivate func adjustingHeight(show: Bool, notification: Notification) {
        var userInfo = notification.userInfo!
        let keyboardFrame: CGRect = (userInfo[UIKeyboardFrameBeginUserInfoKey] as! NSValue).cgRectValue
        //        let animationDurarion = userInfo[UIKeyboardAnimationDurationUserInfoKey] as! TimeInterval
        let changeInHeight = (keyboardFrame.height + 40) * (show ? 1 : -1)
        // Set the table content inset to the keyboard height
        tableView.contentInset.bottom = changeInHeight
    }
    
    @objc func keyboardWillShow(notification: Notification) {
        adjustingHeight(show: true, notification: notification)
    }
    
    @objc func keyboardWillHide(notification: Notification) {
        adjustingHeight(show: false, notification: notification)
    }
}
