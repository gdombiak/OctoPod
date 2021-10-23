import UIKit
import SafariServices  // Used for opening browser in-app

class TerminalViewController: UIViewController, OctoPrintClientDelegate, AppConfigurationDelegate, DefaultPrinterManagerDelegate, UITableViewDelegate, UITableViewDataSource, UIPopoverPresentationControllerDelegate {

    private static let TERMINAL_SUPPRESS_TEMP = "TERMINAL_SUPPRESS_TEMP"
    private static let TERMINAL_SUPPRESS_SD = "TERMINAL_SUPPRESS_SD"

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()
    let defaultPrinterManager: DefaultPrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).defaultPrinterManager }()

    @IBOutlet weak var refreshEnabledTextLabel: UILabel!
    @IBOutlet weak var gcodeTextLabel: UILabel!
    @IBOutlet weak var commandsHistoryView: UIView!
    @IBOutlet weak var commandsHistoryTable: UITableView!
    @IBOutlet weak var dismissHistoryButton: UIButton!
    @IBOutlet weak var popularGCodeButton: UIButton!
    
    @IBOutlet weak var terminalTextView: UITextView!
    @IBOutlet weak var refreshSwitch: UISwitch!
    @IBOutlet weak var gcodeField: UITextField!
    @IBOutlet weak var sendGCodeButton: UIButton!
    @IBOutlet weak var tempFilterButton: UIButton!
    @IBOutlet weak var sdFilterButton: UIButton!
    
    // Gestures to switch between printers
    var swipeLeftGestureRecognizer : UISwipeGestureRecognizer?
    var swipeRightGestureRecognizer : UISwipeGestureRecognizer?

    override func viewDidLoad() {
        super.viewDidLoad()
      
        // Add a border to the (by default) hidden commands history view
        commandsHistoryView.layer.borderWidth = 1.5
        commandsHistoryView.layer.borderColor = UIColor(red: 149/255, green: 170/255, blue: 204/255, alpha: 1.0).cgColor
        
        // Add numbers at the top of keyboard for sending GCODE
        let bar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 35))
        bar.tintColor = .white
        bar.barTintColor = .darkGray
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let b0 = UIBarButtonItem(title: "0", style: .plain, target: self, action: #selector(addNumber(sender:)))
        let b1 = UIBarButtonItem(title: "1", style: .plain, target: self, action: #selector(addNumber(sender:)))
        let b2 = UIBarButtonItem(title: "2", style: .plain, target: self, action: #selector(addNumber(sender:)))
        let b3 = UIBarButtonItem(title: "3", style: .plain, target: self, action: #selector(addNumber(sender:)))
        let b4 = UIBarButtonItem(title: "4", style: .plain, target: self, action: #selector(addNumber(sender:)))
        let b5 = UIBarButtonItem(title: "5", style: .plain, target: self, action: #selector(addNumber(sender:)))
        let b6 = UIBarButtonItem(title: "6", style: .plain, target: self, action: #selector(addNumber(sender:)))
        let b7 = UIBarButtonItem(title: "7", style: .plain, target: self, action: #selector(addNumber(sender:)))
        let b8 = UIBarButtonItem(title: "8", style: .plain, target: self, action: #selector(addNumber(sender:)))
        let b9 = UIBarButtonItem(title: "9", style: .plain, target: self, action: #selector(addNumber(sender:)))
        bar.items = [b1, flexSpace, b2, flexSpace, b3, flexSpace, b4, flexSpace, b5, flexSpace, b6, flexSpace, b7, flexSpace, b8, flexSpace, b9, flexSpace, b0]
        bar.sizeToFit()
        gcodeField.inputAccessoryView = bar
        
        // Restore last saved settings
        if UserDefaults.standard.bool(forKey: TerminalViewController.TERMINAL_SUPPRESS_TEMP) {
            toggleTemperatureFilter(self)
        }
        if UserDefaults.standard.bool(forKey: TerminalViewController.TERMINAL_SUPPRESS_SD) {
            toggleSDFilter(self)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if #available(iOS 13.0, *) {
            // Use monospace font so that tables (eg M122) look better (still not perfect but better)
            // Use whatever point size of callout so we can respect Accessibility configuration
            terminalTextView.font = UIFont.monospacedDigitSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .callout).pointSize, weight: .regular)
        }

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
        // Listen to changes to default printer
        defaultPrinterManager.delegates.append(self)

        // Hide commands history table
        showCommandsHistory(show: false)
        // Apply theme to commands history table
        ThemeUIUtils.applyTheme(table: commandsHistoryTable, staticCells: false)
        // Add gestures to capture swipes and taps on navigation bar
        addNavBarGestures()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Stop listening to events coming from OctoPrintClient
        octoprintClient.remove(octoPrintClientDelegate: self)
        // Stop listening to changes when app is locked or unlocked
        appConfiguration.remove(appConfigurationDelegate: self)
        // Stop listening to changes to default printer
        defaultPrinterManager.remove(defaultPrinterManagerDelegate: self)
        // Remove gestures that capture swipes and taps on navigation bar
        removeNavBarGestures()
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

            // Format the command by uppercasing the tokens except possible label values
            let commandTokens = text.split(separator: " ")

            // Convert to uppercase any words without = or the key part before = and leave the rest as is
            let commandAry : [String] = commandTokens.map {
                if $0.contains("=") {
                    var tokens = $0.components(separatedBy: "=")
                    tokens[0] = tokens[0].uppercased()
                    return tokens.joined(separator: "=")
                } else {
                    return $0.uppercased()
                }
            }
            // Send command to OctoPrint
            let command = commandAry.joined(separator: " ")
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
            // Remember setting in case app gets killed or phone restarted
            UserDefaults.standard.set(false, forKey: TerminalViewController.TERMINAL_SUPPRESS_TEMP)
        } else {
            // Add temperature filter
            octoprintClient.terminal.filters.append(Terminal.Filter.temperature)
            // Update button label
            tempFilterButton.setTitle(NSLocalizedString("Include temp", comment: "Include temp messages in the terminal"), for: .normal)
            // Remember setting in case app gets killed or phone restarted
            UserDefaults.standard.set(true, forKey: TerminalViewController.TERMINAL_SUPPRESS_TEMP)
        }
        self.updateTerminalLogs()
    }
    
    @IBAction func toggleSDFilter(_ sender: Any) {
        if let index = octoprintClient.terminal.filters.firstIndex(of: Terminal.Filter.sd) {
            // Remove temperature filter
            octoprintClient.terminal.filters.remove(at: index)
            // Update button label
            sdFilterButton.setTitle(NSLocalizedString("Suppress SD", comment: "Suppress SD messages in the terminal"), for: .normal)
            // Remember setting in case app gets killed or phone restarted
            UserDefaults.standard.set(false, forKey: TerminalViewController.TERMINAL_SUPPRESS_SD)
        } else {
            // Add temperature filter
            octoprintClient.terminal.filters.append(Terminal.Filter.sd)
            // Update button label
            sdFilterButton.setTitle(NSLocalizedString("Include SD", comment: "Include SD messages in the terminal"), for: .normal)
            // Remember setting in case app gets killed or phone restarted
            UserDefaults.standard.set(true, forKey: TerminalViewController.TERMINAL_SUPPRESS_SD)
        }
        self.updateTerminalLogs()
    }
    
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "gotoPopularGCode" {
            segue.destination.popoverPresentationController!.delegate = self
            // Make the popover appear at the middle of the button
            segue.destination.popoverPresentationController!.sourceRect = CGRect(x: popularGCodeButton.frame.size.width/2, y: popularGCodeButton.frame.size.height/2 , width: 0, height: 0)
        }
    }
    
    // MARK: - Unwind operations

    @IBAction func backFromPopularGCode(_ sender: UIStoryboardSegue) {
        if let controller = sender.source as? PopularGCodeViewController {
            // Replace gcode text with selected from popover
            gcodeField.text = controller.selected
            // Enable send button
            sendGCodeButton.isEnabled = true
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
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        ThemeUIUtils.themeCell(cell: cell)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Update gcode to send from history selection
        gcodeField.text = octoprintClient.terminal.commandsHistory[indexPath.row]
        // Hide history of sent commands
        showCommandsHistory(show: false)
        // Enable send button
        sendGCodeButton.isEnabled = true
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Only allow to delete command from history if app is not locked
        return !appConfiguration.appLocked()
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Remove command from history
            octoprintClient.terminal.removeCommand(position: indexPath.row)
            // Refresh table UI
            commandsHistoryTable.reloadData()
        }
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

    // MARK: - AppConfigurationDelegate
    
    func appLockChanged(locked: Bool) {
        DispatchQueue.main.async {
            self.configureBasedOnAppLockedState()
        }
    }
    
    // MARK: - DefaultPrinterManagerDelegate
    
    func defaultPrinterChanged() {
        DispatchQueue.main.async {
            self.refreshNewSelectedPrinter()
        }
    }
    
    // MARK: - Keyboard Actions
    
    @IBAction func gcodeSendTriggeredFromKeyboard(_ sender: Any) {
        sendGCode(sender)
    }
    
    // MARK: - Private - Navigation Bar Gestures

    fileprivate func addNavBarGestures() {
        // Add gesture when we swipe from right to left
        swipeLeftGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(navigationBarSwiped(_:)))
        swipeLeftGestureRecognizer!.direction = .left
        navigationController?.navigationBar.addGestureRecognizer(swipeLeftGestureRecognizer!)
        swipeLeftGestureRecognizer!.cancelsTouchesInView = false
        
        // Add gesture when we swipe from left to right
        swipeRightGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(navigationBarSwiped(_:)))
        swipeRightGestureRecognizer!.direction = .right
        navigationController?.navigationBar.addGestureRecognizer(swipeRightGestureRecognizer!)
        swipeRightGestureRecognizer!.cancelsTouchesInView = false
    }

    fileprivate func removeNavBarGestures() {
        if let swipeLeftGestureRecognizer = swipeLeftGestureRecognizer {
            // Remove gesture when we swipe from right to left
            navigationController?.navigationBar.removeGestureRecognizer(swipeLeftGestureRecognizer)
        }
        
        if let swipeRightGestureRecognizer = swipeRightGestureRecognizer {
            // Remove gesture when we swipe from left to right
            navigationController?.navigationBar.removeGestureRecognizer(swipeRightGestureRecognizer)
        }
    }

    @objc fileprivate func navigationBarSwiped(_ gesture: UIGestureRecognizer) {
        // Change default printer
        let direction: DefaultPrinterManager.SwipeDirection = gesture == swipeLeftGestureRecognizer ? .left : .right
        defaultPrinterManager.navigationBarSwiped(direction: direction)
    }

    // MARK: - Private functions

    fileprivate func configureBasedOnAppLockedState() {
        // Enable sending gcode commands only if app is not locked
        gcodeField.isEnabled = !appConfiguration.appLocked()
    }
    
    @objc fileprivate func addNumber(sender: UIBarButtonItem) {
        if let title = sender.title {
            gcodeField.text!.append(title)
        }
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
        let tintColor = theme.tintColor()

        view.backgroundColor = theme.backgroundColor()
        
        refreshEnabledTextLabel.textColor = textLabelColor
        gcodeTextLabel.textColor = textLabelColor
        gcodeField.textColor = textColor
        popularGCodeButton.tintColor = tintColor
        
        terminalTextView.backgroundColor = theme.cellBackgroundColor()
        terminalTextView.textColor = textColor
        
        tempFilterButton.tintColor = tintColor
        sdFilterButton.tintColor = tintColor
    }
    
    fileprivate func showAlert(_ title: String, message: String) {
        UIUtils.showAlert(presenter: self, title: title, message: message, done: nil)
    }
}
