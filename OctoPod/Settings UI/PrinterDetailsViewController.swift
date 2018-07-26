import UIKit

class PrinterDetailsViewController: ThemedStaticUITableViewController {
    
    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    
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
            printerNameField.text = selectedPrinter.name
            hostnameField.text = selectedPrinter.hostname
            // Hide or show URL error message
            urlErrorMessageLabel.isHidden = isValidURL()
            apiKeyField.text = scannedKey == nil ? selectedPrinter.apiKey : scannedKey
            usernameField.text = selectedPrinter.username
            passwordField.text = selectedPrinter.password
        } else {
            // Hide URL error message
            urlErrorMessageLabel.isHidden = true
        }

        // Register for keyboard notifications
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: .UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: .UIKeyboardWillHide, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        // Unregister for keyboard notifications
        NotificationCenter.default.removeObserver(self)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func cancelChanges(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func saveChanges(_ sender: Any) {
        if let printer = updatePrinter {
            // Update existing printer
            printer.name = printerNameField.text!
            printer.hostname = hostnameField.text!
            printer.apiKey = apiKeyField.text!
            
            printer.username = usernameField.text
            printer.password = passwordField.text
            
            printerManager.updatePrinter(printer)
        } else {
            // Add new printer (that will become default if it's the first one)
            printerManager.addPrinter(name: printerNameField.text!, hostname: hostnameField.text!, apiKey: apiKeyField.text!, username: usernameField.text, password: passwordField.text)
        }
        
        // Go back to previous page and execute the unwinsScanQRCode IBAction
        performSegue(withIdentifier: "unwindPrintersUpdated", sender: self)
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

    fileprivate func updateSaveButton() {
        if !(printerNameField.text?.isEmpty)! && !(hostnameField.text?.isEmpty)! && !(apiKeyField.text?.isEmpty)! {
            saveButton.isEnabled = isValidURL()
        } else {
            saveButton.isEnabled = false
        }
    }
    
    fileprivate func isValidURL() -> Bool {
        if let inputURL = hostnameField.text {
            let urlRegEx = "(http|https)://((\\w)*|([0-9]*)|([-|_])*)+([\\.|/]((\\w)*|([0-9]*)|([-|_])*))+(:[0-9]+)?"
            let urlTest = NSPredicate(format: "SELF MATCHES %@", urlRegEx)
            let result = urlTest.evaluate(with: inputURL)
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
