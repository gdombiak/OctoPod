import UIKit

class Palette2ViewController: ThemedStaticUITableViewController, SubpanelViewController, OctoPrintPluginsDelegate, UIPopoverPresentationControllerDelegate {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()

    @IBOutlet weak var connectionStatusLabel: UILabel!
    @IBOutlet weak var connectionStatusValueLabel: UILabel!
    @IBOutlet weak var paletteStatusLabel: UILabel!
    @IBOutlet weak var paletteStatusValueLabel: UILabel!
    @IBOutlet weak var spliceLabel: UILabel!
    @IBOutlet weak var spliceCurrentLabel: UILabel!
    @IBOutlet weak var spliceOfLabel: UILabel!
    @IBOutlet weak var spliceTotalLabel: UILabel!
    @IBOutlet weak var filamentUsedLabel: UILabel!
    @IBOutlet weak var filamentUsedValueLabel: UILabel!
    @IBOutlet weak var filamentUsedUnitLabel: UILabel!
    @IBOutlet weak var latestPingLabel: UILabel!
    @IBOutlet weak var latestPingNumberLabel: UILabel!
    @IBOutlet weak var latestPingNumberValueLabel: UILabel!
    @IBOutlet weak var latestPingOffsetLabel: UILabel!
    @IBOutlet weak var latestPingOffsetValueLabel: UILabel!
    @IBOutlet weak var latestPongLabel: UILabel!
    @IBOutlet weak var latestPongNumberLabel: UILabel!
    @IBOutlet weak var latestPongNumberValueLabel: UILabel!
    @IBOutlet weak var latestPongOffsetLabel: UILabel!
    @IBOutlet weak var latestPongOffsetValueLabel: UILabel!

    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var selectPortButton: UIButton!
    @IBOutlet weak var cutButton: UIButton!
    @IBOutlet weak var clearPaletteButton: UIButton!
    
    var selectedPort: String?
    var connected: Bool?
    var pingsHistory: Array<Dictionary<String,Any>>?
    var pongsHistory: Array<Dictionary<String,Any>>?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Register custom section view we use for showing an image
        tableView.register(SectionHeaderView.self, forHeaderFooterViewReuseIdentifier: SectionHeaderView.reuseIdentifier)

        // Some bug in XCode Storyboards is not translating text of refresh control so let's do it manually
        self.refreshControl?.attributedTitle = NSAttributedString(string: NSLocalizedString("Pull down to refresh", comment: ""))
        
        // Reset UI values and ignore storyboard dummy values
        self.resetUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Theme labels
        themeLabels()

        // Configure UI based on app locked state
        configureBasedOnAppLockedState()

        // Listen to changes to OctoPrint Plugin messages
        octoprintClient.octoPrintPluginsDelegates.append(self)

        // Fetch and render palette status
        refreshStatus(refreshUI: false, done: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Stop listening to changes to OctoPrint Plugin messages
        octoprintClient.remove(octoPrintPluginsDelegate: self)
    }

    // MARK: - Button operations

    @IBAction func connectDisconnectClicked(_ sender: Any) {
        if connected == true {
            // Prompt before trying to disconnect from Palette
            showConfirm(message: NSLocalizedString("Confirm disconnect palette2", comment: ""), yes: { (UIAlertAction) in
                self.octoprintClient.palette2Disconnect { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                    if !requested {
                        self.showAndLogAlert(error, response, "Palette - Error requesting to disconnect", NSLocalizedString("Failed to request to disconnect", comment: ""))
                    }
                }
            }) { (UIAlertAction) in
                // Do nothing
            }
        } else {
            // Connect to Palette
            let port = selectedPort == nil ? "" : selectedPort!
            octoprintClient.palette2Connect(port: port) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                if !requested {
                    if response.statusCode == 500 {
                        // Palette is offline or not connected or incorrect baudrate or some connectivity error
                        self.showAndLogAlert(error, response, "Palette - Failed to connect", NSLocalizedString("Failed to connect", comment: ""))
                    } else {
                        self.showAndLogAlert(error, response, "Palette - Error requesting to connect", NSLocalizedString("Failed to request to connect", comment: ""))
                    }
                }
            }
        }
    }
    
    @IBAction func cutClicked(_ sender: Any) {
        octoprintClient.palette2Cut { (requested: Bool, error: Error?, response: HTTPURLResponse) in
            if !requested {
                self.showAndLogAlert(error, response, "Palette - Error requesting to cut", NSLocalizedString("Failed to request to cut", comment: ""))
            }
        }
    }
    
    @IBAction func clearPaletteClicked(_ sender: Any) {
        octoprintClient.palette2Clear { (requested: Bool, error: Error?, response: HTTPURLResponse) in
            if !requested {
                self.showAndLogAlert(error, response, "Palette - Error requesting to clear", NSLocalizedString("Failed to request to clear", comment: ""))
            }
        }
    }
    
    // MARK: - Table view delegate

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let customFooterView = tableView.dequeueReusableHeaderFooterView(withIdentifier: SectionHeaderView.reuseIdentifier) as! SectionHeaderView
        if section == 0 {
            customFooterView.imageView.isHidden = false
            customFooterView.imageView.image = UIImage(named: "Palette2")
        } else {
            customFooterView.imageView.isHidden = true
            customFooterView.imageView.image = nil
        }
        return customFooterView
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 0 ? 34 : 28
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 6
    }

    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "change_port", let controller = segue.destination as? Palette2PortsViewController {
            controller.popoverPresentationController!.delegate = self
            // Set last selected port
            controller.selectedPort = selectedPort
            // Make the popover appear at the middle of the button
            segue.destination.popoverPresentationController!.sourceRect = CGRect(x: 0, y: selectPortButton.frame.size.height/2 , width: 0, height: 0)
        } else if segue.identifier == "show_ping_history", let controller = segue.destination as? PingPongHistoryViewController {
            controller.history = pingsHistory
            controller.title = NSLocalizedString("Ping History", comment: "")
        } else if segue.identifier == "show_pong_history", let controller = segue.destination as? PingPongHistoryViewController {
            controller.history = pongsHistory
            controller.title = NSLocalizedString("Pong History", comment: "")
        }
    }

    // MARK: - Unwind operations
    
    @IBAction func backFromChangePorts(_ sender: UIStoryboardSegue) {
        if let controller = sender.source as? Palette2PortsViewController {
            selectedPort = controller.selectedPort
        }
    }
    
    // MARK: - SubpanelViewController
    
    func printerSelectedChanged() {
        // Only refresh UI if view controller is being shown
        if let _ = parent {
            // Fetch and render palette status
            refreshStatus(refreshUI: true, done: nil)
        }
    }
    
    func currentStateUpdated(event: CurrentStateEvent) {
        // Do nothing
    }
    
    func position() -> Int {
        return 11
    }
    
    // MARK: - UIPopoverPresentationControllerDelegate
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }
    
    // We need to add this so it works on iPhone plus in landscape mode
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }
    
    // MARK: - OctoPrintPluginsDelegate
    
    func pluginMessage(plugin: String, data: NSDictionary) {
        if plugin == Plugins.PALETTE_2 {
            if let command = data["command"] as? String {
                if command == "p2Connection", let connected = data["data"] as? Bool {
                    // Connnected to Palette 2
                    var status: String!
                    var button: String = NSLocalizedString("Connect", comment: "Connect")
                    if connected {
                        status = NSLocalizedString("Connected", comment: "Connected")
                        button = NSLocalizedString("Disconnect", comment: "Disconnect")
                    } else if let printer = printerManager.getDefaultPrinter() {
                        status = printer.palette2AutoConnect ? NSLocalizedString("Connecting", comment: "Connecting") : NSLocalizedString("Disconnected", comment: "Disconnected")
                    }
                    // Update cached value
                    self.connected = connected
                    // Refresh UI
                    DispatchQueue.main.async {
                        self.connectionStatusValueLabel.text = status
                        self.connectButton.setTitle(button, for: .normal)
                        // Enable/Disable buttons based on connection status
                        self.selectPortButton.isEnabled = !connected
                        self.cutButton.isEnabled = connected
                        self.clearPaletteButton.isEnabled = connected
                    }
                } else if command == "filamentLength", let length = data["data"] as? Int {
                    // Length of filament used so far
                    DispatchQueue.main.async {
                        self.filamentUsedValueLabel.text = "\(length)"
                    }
                } else if command == "currentStatus" {
                    // Palette 2 Status
                    var status = data["data"] as? String
                    if status == nil || status!.isEmpty {
                        status = NSLocalizedString("Idle", comment: "Idle")
                    }
                    DispatchQueue.main.async {
                        self.paletteStatusValueLabel.text = status
                    }
                } else if command == "selectedPort", let port = data["data"] as? String {
                    // Current port being used by OctoPrint server to connect to Palette 2
                    selectedPort = port
                } else if command == "pings", let pings = data["data"] as? Array<Dictionary<String,Any>> {
                    // History of pings to Palette 2 device.
                    // A Ping is a checkpoint that compares the filament used with the amount expected
                    // Adjustments are automacatlly done by Palette based on this information
                    pingsHistory = pings
                    if pings.isEmpty {
                        // Reset displayed values
                        DispatchQueue.main.async {
                            self.resetLatestPingUI()
                        }
                    } else {
                        // Show latest ping values
                        if let messages = Palette2ViewController.pingPongMessage(entry: pings[0]) {
                            DispatchQueue.main.async {
                                self.latestPingNumberValueLabel.text = messages.number
                                self.latestPingOffsetValueLabel.text = messages.percent
                            }
                        }
                    }
                } else if command == "pongs", let pongs = data["data"] as? Array<Dictionary<String,Any>> {
                    // History of pongs from Palette 2 device
                    // Pongs help Palette make sure its own filament production is accurate
                    // Adjustments are automacatlly done by Palette based on this information
                    pongsHistory = pongs
                    if pongs.isEmpty {
                        // Reset displayed values
                        DispatchQueue.main.async {
                            self.resetLatestPongUI()
                        }
                    } else {
                        // Show latest pong values
                        if let messages = Palette2ViewController.pingPongMessage(entry: pongs[0]) {
                            DispatchQueue.main.async {
                                self.latestPongNumberValueLabel.text = messages.number
                                self.latestPongOffsetValueLabel.text = messages.percent
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Refresh
    
    @IBAction func refreshControls(_ sender: UIRefreshControl) {
        // Fetch and render custom controls
        refreshStatus(refreshUI: true, done: {
            DispatchQueue.main.async {
                sender.endRefreshing()
            }
        })
    }
    
    // MARK: - Private functions
    
    fileprivate func configureBasedOnAppLockedState() {
        // Enable buttons only if app is not locked
        connectButton.isEnabled = !appConfiguration.appLocked()
        cutButton.isEnabled = !appConfiguration.appLocked()
        clearPaletteButton.isEnabled = !appConfiguration.appLocked()
        selectPortButton.isEnabled = !appConfiguration.appLocked()
    }

    fileprivate func resetUI() {
        self.connectionStatusValueLabel.text = nil
        self.paletteStatusValueLabel.text = nil
        self.spliceCurrentLabel.text = "0"
        self.spliceTotalLabel.text = "0"
        self.filamentUsedValueLabel.text = "0"
        resetLatestPingUI()
        resetLatestPongUI()
    }
    
    fileprivate func resetLatestPingUI() {
        self.latestPingNumberValueLabel.text = "0"
        self.latestPingOffsetValueLabel.text = "-- %"
    }
    
    fileprivate func resetLatestPongUI() {
        self.latestPongNumberValueLabel.text = "0"
        self.latestPongOffsetValueLabel.text = "-- %"
    }
    
    fileprivate func refreshStatus(refreshUI: Bool, done: (() -> Void)?) {
        // Cleaned up cached values
        selectedPort = nil
        connected = nil
        pingsHistory = nil
        pongsHistory = nil
        if refreshUI {
            DispatchQueue.main.async {
                self.resetUI()
            }
        }
        // Request OctoPrint plugin to send latest status. Results will come via websockets. See #pluginMessage(plugin:data:)
        octoprintClient.palette2Status { (requested: Bool, error: Error?, response: HTTPURLResponse) in
            if !requested {
                self.showAndLogAlert(error, response, "Palette - Error requesting status", NSLocalizedString("Failed to request status", comment: ""))
            }

            // Execute done block when done
            done?()
        }
    }

    fileprivate func themeLabels() {
        let theme = Theme.currentTheme()
        let textLabelColor = theme.labelColor()
        let textColor = theme.textColor()
        let tintColor = theme.tintColor()
        connectionStatusLabel.textColor = textLabelColor
        connectionStatusValueLabel.textColor = textColor
        paletteStatusLabel.textColor = textLabelColor
        paletteStatusValueLabel.textColor = textColor
        spliceLabel.textColor = textLabelColor
        spliceCurrentLabel.textColor = textColor
        spliceOfLabel.textColor = textLabelColor
        spliceTotalLabel.textColor = textColor
        filamentUsedLabel.textColor = textLabelColor
        filamentUsedValueLabel.textColor = textColor
        filamentUsedUnitLabel.textColor = textLabelColor
        latestPingLabel.textColor = textLabelColor
        latestPingNumberLabel.textColor = textLabelColor
        latestPingNumberValueLabel.textColor = textColor
        latestPingOffsetLabel.textColor = textLabelColor
        latestPingOffsetValueLabel.textColor = textColor
        latestPongLabel.textColor = textLabelColor
        latestPongNumberLabel.textColor = textLabelColor
        latestPongNumberValueLabel.textColor = textColor
        latestPongOffsetLabel.textColor = textLabelColor
        latestPongOffsetValueLabel.textColor = textColor
        connectButton.tintColor = tintColor
        cutButton.tintColor = tintColor
        clearPaletteButton.tintColor = tintColor
        selectPortButton.tintColor = tintColor
    }
    
    fileprivate func showAndLogAlert(_ error: Error?, _ response: HTTPURLResponse, _ log: String, _ message: String) {
        if let error = error {
            NSLog("\(log). Error: \(error.localizedDescription)")
        } else {
            NSLog("\(log). Error: \(response.statusCode)")
        }
        UIUtils.showAlert(presenter: self, title: NSLocalizedString("Warning", comment: ""), message: message, done: nil)
    }
    
    fileprivate func showConfirm(message: String, yes: @escaping (UIAlertAction) -> Void, no: @escaping (UIAlertAction) -> Void) {
        UIUtils.showConfirm(presenter: self, message: message, yes: yes, no: no)
    }
    
    // MARK: - Static functions
    
    static func pingPongMessage(entry: Dictionary<String,Any>) -> (number: String, percent: String)? {
        if let number = entry["number"] as? Int, let percent = entry["percent"] as? String {
            return ("\(number)" , percent == "MISSED" ? NSLocalizedString("Missed", comment: "") : "\(percent) %")
        }
        return nil
    }
}

final class SectionHeaderView: UITableViewHeaderFooterView {
    static let reuseIdentifier: String = String(describing: self)
    
    var imageView: UIImageView
    
    override init(reuseIdentifier: String?) {
        imageView = UIImageView()
        super.init(reuseIdentifier: reuseIdentifier)
        
        contentView.addSubview(imageView)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        imageView.widthAnchor.constraint(equalToConstant: 32.0).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 32.0).isActive = true
        if let superView = contentView.superview {
            imageView.trailingAnchor.constraint(equalTo: superView.trailingAnchor,constant: -16).isActive = true
            imageView.bottomAnchor.constraint(equalTo: superView.bottomAnchor, constant: -1).isActive = true
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        imageView = UIImageView()
        super.init(coder: aDecoder)
    }
}
