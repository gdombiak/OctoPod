import UIKit

class PrinterDetailsViewController: UITableViewController {
    
    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    
    var updatePrinter: Printer? = nil
    var scannedKey: String?

    @IBOutlet weak var printerNameLabel: UITextField!
    @IBOutlet weak var hostnameLabel: UITextField!
    @IBOutlet weak var apiKeyLabel: UITextField!
    
    @IBOutlet weak var usernameLabel: UITextField!
    @IBOutlet weak var passwordLabel: UITextField!
    
    @IBOutlet weak var saveButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if let selectedPrinter = updatePrinter {
            printerNameLabel.text = selectedPrinter.name
            hostnameLabel.text = selectedPrinter.hostname
            apiKeyLabel.text = scannedKey == nil ? selectedPrinter.apiKey : scannedKey
            usernameLabel.text = selectedPrinter.username
            passwordLabel.text = selectedPrinter.password
        }
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
            printer.name = printerNameLabel.text!
            printer.hostname = hostnameLabel.text!
            printer.apiKey = apiKeyLabel.text!
            
            printer.username = usernameLabel.text
            printer.password = passwordLabel.text
            
            printerManager.updatePrinter(printer)
        } else {
            // Add new printer (that will become default if it's the first one)
            printerManager.addPrinter(name: printerNameLabel.text!, hostname: hostnameLabel.text!, apiKey: apiKeyLabel.text!, username: usernameLabel.text, password: passwordLabel.text)
        }
        
        // Go back to previous page and execute the unwinsScanQRCode IBAction
        performSegue(withIdentifier: "unwindPrintersUpdated", sender: self)
    }
    
    @IBAction func fieldChanged(_ sender: Any) {
        updateSaveButton()
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
            self.apiKeyLabel.text = scanner.scannedQRCode
            scannedKey = scanner.scannedQRCode
            self.updateSaveButton()
        }
    }

    fileprivate func updateSaveButton() {
        if !(printerNameLabel.text?.isEmpty)! && !(hostnameLabel.text?.isEmpty)! && !(apiKeyLabel.text?.isEmpty)! {
            saveButton.isEnabled = isValidURL()
        } else {
            saveButton.isEnabled = false
        }
    }
    
    fileprivate func isValidURL() -> Bool {
        if let inputURL = hostnameLabel.text {
            let urlRegEx = "(http|https)://((\\w)*|([0-9]*)|([-|_])*)+([\\.|/]((\\w)*|([0-9]*)|([-|_])*))+(:[0-9]+)?"
            let urlTest = NSPredicate(format: "SELF MATCHES %@", urlRegEx)
            let result = urlTest.evaluate(with: inputURL)
            return result
        }
        return false
    }
}
