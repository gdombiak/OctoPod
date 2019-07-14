import UIKit
import SafariServices  // Used for opening browser in-app

class TerminalViewController: UIViewController, OctoPrintClientDelegate, AppConfigurationDelegate, WatchSessionManagerDelegate, UITableViewDelegate, UITableViewDataSource {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()
    let watchSessionManager: WatchSessionManager = { return (UIApplication.shared.delegate as! AppDelegate).watchSessionManager }()

    @IBOutlet weak var refreshEnabledTextLabel: UILabel!
    @IBOutlet weak var gcodeTextLabel: UILabel!
    @IBOutlet weak var commandsHistoryView: UIView!
    @IBOutlet weak var commandsHistoryTable: UITableView!
    @IBOutlet weak var dismissHistoryButton: UIButton!
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var terminalTextView: UITextView!
    @IBOutlet weak var refreshSwitch: UISwitch!
    @IBOutlet weak var gcodeField: UITextField!
    @IBOutlet weak var sendGCodeButton: UIButton!
    @IBOutlet weak var tempFilterButton: UIButton!
    @IBOutlet weak var sdFilterButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
      
        // Add a border to the (by default) hidden commands history view
        commandsHistoryView.layer.borderWidth = 1.5
        commandsHistoryView.layer.borderColor = UIColor(red: 149/255, green: 170/255, blue: 204/255, alpha: 1.0).cgColor
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
        
        // Hide commands history table
        showCommandsHistory(show: false)
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

    @IBAction func gcodeEntered(_ sender: Any) {
        // User clicked on gcode field so display commands history if there is something in the history
        let hide = octoprintClient.terminal.commandsHistory.isEmpty
        showCommandsHistory(show: !hide)
        if !hide {
            commandsHistoryTable.reloadData()
        }
    }
    
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
            // Hide history of sent commands
            showCommandsHistory(show: false)
            // Send command to OctoPrint
            let command = text.uppercased()
            octoprintClient.sendCommand(gcode: command) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
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
            // Add new command to the history of sent commands
            octoprintClient.terminal.addCommand(command: command)
        }
    }

    @IBAction func toggleTemperatureFilter(_ sender: Any) {
        if let index = octoprintClient.terminal.filters.firstIndex(of: Terminal.Filter.temperature) {
            // Remove temperature filter
            octoprintClient.terminal.filters.remove(at: index)
            // Update button label
            tempFilterButton.setTitle(NSLocalizedString("Suppress temp", comment: "Suppress temp messages in the terminal"), for: .normal)
        } else {
            // Add temperature filter
            octoprintClient.terminal.filters.append(Terminal.Filter.temperature)
            // Update button label
            tempFilterButton.setTitle(NSLocalizedString("Include temp", comment: "Include temp messages in the terminal"), for: .normal)
        }
        self.updateTerminalLogs()
    }
    
    @IBAction func toggleSDFilter(_ sender: Any) {
        if let index = octoprintClient.terminal.filters.firstIndex(of: Terminal.Filter.sd) {
            // Remove temperature filter
            octoprintClient.terminal.filters.remove(at: index)
            // Update button label
            sdFilterButton.setTitle(NSLocalizedString("Suppress SD", comment: "Suppress SD messages in the terminal"), for: .normal)
        } else {
            // Add temperature filter
            octoprintClient.terminal.filters.append(Terminal.Filter.sd)
            // Update button label
            sdFilterButton.setTitle(NSLocalizedString("Include SD", comment: "Include SD messages in the terminal"), for: .normal)
        }
        self.updateTerminalLogs()
    }
    
    // MARK: - Commands History
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return commandsHistoryTable.isHidden ? 0 : 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return octoprintClient.terminal.commandsHistory.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "sent_command", for: indexPath)
        
        // Configure the cell...
        cell.textLabel?.text = octoprintClient.terminal.commandsHistory[indexPath.row]
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Update gcode to send from history selection
        gcodeField.text = octoprintClient.terminal.commandsHistory[indexPath.row]
        // Hide history of sent commands
        showCommandsHistory(show: false)
        // Enable send button
        sendGCodeButton.isEnabled = true
    }
    
    @IBAction func dismissCommandsHistory(_ sender: Any) {
        showCommandsHistory(show: false)
    }
    
    fileprivate func showCommandsHistory(show: Bool) {
        commandsHistoryTable.isHidden = !show
        dismissHistoryButton.isHidden = !show
        commandsHistoryView.isHidden = !show
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
        tempFilterButton.isEnabled = refreshSwitch.isOn
        sdFilterButton.isEnabled = refreshSwitch.isOn
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
            let terminal = octoprintClient.terminal
            let log = terminal.filters.isEmpty ? terminal.logs : terminal.filteredLog
            let logsText = log.joined(separator: "\n")
            terminalTextView.text = logsText
            // If text is not empty then scroll to bottom (this prevents an app crash with NSBigMutableString)
            if terminalTextView.text.count > 1 {
                // Keep scrolling to the bottom
                let bottom = NSMakeRange(terminalTextView.text.count - 1, 1)
                terminalTextView.scrollRangeToVisible(bottom)
            }
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
