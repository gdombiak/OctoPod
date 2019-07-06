import UIKit
import SafariServices  // Used for opening browser in-app

class TerminalViewController: UIViewController, OctoPrintClientDelegate, AppConfigurationDelegate, WatchSessionManagerDelegate {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()
    let watchSessionManager: WatchSessionManager = { return (UIApplication.shared.delegate as! AppDelegate).watchSessionManager }()

    @IBOutlet weak var refreshEnabledTextLabel: UILabel!
    @IBOutlet weak var gcodeTextLabel: UILabel!
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var terminalTextView: UITextView!
    @IBOutlet weak var refreshSwitch: UISwitch!
    @IBOutlet weak var gcodeField: UITextField!
    @IBOutlet weak var sendGCodeButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        terminalTextView.layer.borderWidth = 1
        terminalTextView.layer.borderColor = UIColor.black.cgColor
        themeLabels()

        refreshNewSelectedPrinter()
        
        // Configure UI based on app locked state
        configureBasedOnAppLockedState()

        // Listen to events coming from OctoPrintClient
        octoprintClient.delegates.append(self)
        // Listen to changes when app is locked or unlocked
        appConfiguration.delegates.append(self)
        // Listen to changes coming from Apple Watch
        watchSessionManager.delegates.append(self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // Stop listening to events coming from OctoPrintClient
        octoprintClient.remove(octoPrintClientDelegate: self)
        // Stop listening to changes when app is locked or unlocked
        appConfiguration.remove(appConfigurationDelegate: self)
        // Stop listening to changes coming from Apple Watch
        watchSessionManager.remove(watchSessionManagerDelegate: self)
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
                    var message = NSLocalizedString("Failed to send GCode command", comment: "")
                    if response.statusCode == 409 {
                        message = NSLocalizedString("Printer not operational", comment: "")
                    }
                    self.showAlert(NSLocalizedString("Warning", comment: ""), message: message)
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
    
    func printerStateUpdated(event: CurrentStateEvent) {
        if let _ = event.logs {
            DispatchQueue.main.async {
                self.updateTerminalLogs()
            }
        }
    }
    
    func websocketConnected() {
    }
    
    func websocketConnectionFailed(error: Error) {
    }
    
    func notificationAboutToConnectToServer() {
    }
    
    func handleConnectionError(error: Error?, response: HTTPURLResponse) {
    }

    // MARK: - AppConfigurationDelegate
    
    func appLockChanged(locked: Bool) {
        DispatchQueue.main.async {
            self.configureBasedOnAppLockedState()
        }
    }
    
    // MARK: - WatchSessionManagerDelegate
    
    // Notification that a new default printer has been selected from the Apple Watch app
    func defaultPrinterChanged() {
        DispatchQueue.main.async {
            self.refreshNewSelectedPrinter()
        }
    }
    
    // MARK: - Private functions

    fileprivate func configureBasedOnAppLockedState() {
        // Enable sending gcode commands only if app is not locked
        gcodeField.isEnabled = !appConfiguration.appLocked()
    }
    
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

    fileprivate func refreshNewSelectedPrinter() {
        if let printer = printerManager.getDefaultPrinter() {
            // Update window title to Camera name
            navigationItem.title = printer.name
        } else {
            navigationItem.title = NSLocalizedString("Terminal", comment: "")
        }
        updateTerminalLogs()
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
        UIUtils.showAlert(presenter: self, title: title, message: message, done: nil)
    }
}
