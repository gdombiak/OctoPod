import UIKit
import SafariServices  // Used for opening browser in-app

class TerminalViewController: UIViewController, OctoPrintClientDelegate {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()

    @IBOutlet weak var refreshEnabledTextLabel: UILabel!
    @IBOutlet weak var gcodeTextLabel: UILabel!
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var terminalTextView: UITextView!
    @IBOutlet weak var refreshSwitch: UISwitch!
    @IBOutlet weak var gcodeField: UITextField!
    @IBOutlet weak var sendGCodeButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Listen to events coming from OctoPrintClient
        octoprintClient.delegates.append(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        terminalTextView.layer.borderWidth = 1
        terminalTextView.layer.borderColor = UIColor.black.cgColor
        themeLabels()

        if let printer = printerManager.getDefaultPrinter() {
            // Update window title to Camera name
            navigationItem.title = printer.name
        } else {
            navigationItem.title = "Terminal"
        }

        updateTerminalLogs()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - GCode operations

    @IBAction func gcodeChanged(_ sender: Any) {
        var buttonEnabled = false
        if let text = gcodeField.text {
            buttonEnabled = !text.isEmpty
        }
        sendGCodeButton.isEnabled = buttonEnabled
    }
    
    @IBAction func sendGCode(_ sender: Any) {
        if let text = gcodeField.text {
            // We are done editing the field so hide the keyboard
            gcodeField.endEditing(true)
            // Send command to OctoPrint
            octoprintClient.sendCommand(gcode: text.uppercased()) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                if !requested {
                    // Handle error
                    var message = "Failed to send GCode command"
                    if response.statusCode == 409 {
                        message = "Printer not operational"
                    }
                    self.showAlert("Alert", message: message)
                } else {
                    // Command successfully requested
                    DispatchQueue.main.async {
                        // Clean up entered command so new one can be entered
                        self.gcodeField.text = nil
                        // Disable send button
                        self.gcodeChanged(self)
                    }
                }
            }
        }
    }

    // MARK: - OctoPrint Web operations
    
    @IBAction func openOctoPrintWeb(_ sender: Any) {
        if let printer = printerManager.getDefaultPrinter() {            
            let svc = SFSafariViewController(url: URL(string: printer.hostname)!)
            self.present(svc, animated: true, completion: nil)
        }
    }
    
    // MARK: - Refresh switch operations
    
    @IBAction func refreshChanged(_ sender: Any) {
        if refreshSwitch.isOn {
            // Update terminal now so UI has latest instead of waiting for new update from OctoPrint to update UI
            updateTerminalLogs()
        }
    }
    
    // MARK: - OctoPrintClientDelegate
    
    // Notification that OctoPrint state has changed. This may include printer status information
    func printerStateUpdated(event: CurrentStateEvent) {
        if let _ = event.logs {
            DispatchQueue.main.async {
                self.updateTerminalLogs()
            }
        }
    }
    
    // Notification sent when websockets got connected
    func websocketConnected() {
    }
    
    // Notification sent when websockets got disconnected due to an error (or failed to connect)
    func websocketConnectionFailed(error: Error) {
    }
    
    // Notification that we are about to connect to OctoPrint server
    func notificationAboutToConnectToServer() {
    }
    
    // Notification that HTTP request failed (connection error, authentication error or unexpect http status code)
    func handleConnectionError(error: Error?, response: HTTPURLResponse) {
    }

    // MARK: - Private functions

    // Make sure to call this function from main thread
    fileprivate func updateTerminalLogs() {
        if refreshSwitch.isOn {
            let logsText = octoprintClient.terminal.logs.joined(separator: "\n")
            terminalTextView.text = logsText
            // Keep scrolling to the bottom
            let bottom = NSMakeRange(terminalTextView.text.count - 1, 1)
            terminalTextView.scrollRangeToVisible(bottom)
        }
    }

    fileprivate func themeLabels() {
        let theme = Theme.currentTheme()
        let textLabelColor = theme.labelColor()
        let textColor = theme.textColor()

        view.backgroundColor = theme.backgroundColor()
        
        refreshEnabledTextLabel.textColor = textLabelColor
        gcodeTextLabel.textColor = textLabelColor
        
        terminalTextView.backgroundColor = theme.cellBackgroundColor()
        terminalTextView.textColor = textColor
    }
    
    fileprivate func showAlert(_ title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: { (UIAlertAction) -> Void in
            // Nothing to do here
        }))
        // Present dialog on main thread to prevent crashes
        DispatchQueue.main.async {
            self.present(alert, animated: true) { () -> Void in
                // Nothing to do here
            }
        }
    }
}
