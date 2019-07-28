import UIKit

// It happens that 3 plugins were done by the same developer and share the same API. We can reuse this
// class to control any of the these 3 plugins (and maybe more from the same developer)
// Plugins that use an IPPlug (IP Address and Label) can use this VC
class IPPlugViewController: ThemedDynamicUITableViewController, SubpanelViewController, OctoPrintSettingsDelegate, OctoPrintPluginsDelegate {
    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()

    var ipPlugPlugin: String!
    
    var plugs: [IPPlug] = []
    var plugsState: Dictionary<String, Bool> = Dictionary()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Get list of plugs for selected printer
        refreshPlugs()
        // Refresh table
        self.tableView.reloadData()
        // Listen to changes to OctoPrint Plugin messages
        octoprintClient.octoPrintPluginsDelegates.append(self)
        // Listen to changes to OctoPrint Settings
        octoprintClient.octoPrintSettingsDelegates.append(self)
        // For each plug we need to check its state (answer will be reported via websockets)
        checkPlugsState()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Stop listening to changes to OctoPrint Plugin messages
        octoprintClient.remove(octoPrintPluginsDelegate: self)
        // Stop listening to changes to OctoPrint Settings
        octoprintClient.remove(octoPrintSettingsDelegate: self)
    }

    // MARK: - SubpanelViewController
    
    func printerSelectedChanged() {
        // Reset state if plugs
        plugsState = Dictionary()
        // Only refresh UI if view controller is being shown
        if let _ = parent {
            // Get list of plugs for selected printer
            refreshPlugs()
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    func currentStateUpdated(event: CurrentStateEvent) {
        // Do nothing
    }
    
    func position() -> Int {
        return 40
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return plugs.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ip_plug_cell", for: indexPath) as! IPPlugTableViewCell
        let plug = plugs[indexPath.row]
        
        let label = cell.titleLabel
        label?.text = plug.label
        label?.textColor = Theme.currentTheme().labelColor()
        
        let state: Bool? = plugsState[plug.ip]
        cell.setPowerState(isPowerOn: state)
        
        cell.parentVC = self
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch ipPlugPlugin! {
        case Plugins.TP_LINK_SMARTPLUG:
            return NSLocalizedString("TPLink Smartplugs", comment: "")
        case Plugins.WEMO_SWITCH:
            return NSLocalizedString("Wemo Switches", comment: "")
        case Plugins.DOMOTICZ:
            return NSLocalizedString("Domoticz Plugs", comment: "")
        case Plugins.TASMOTA:
            return NSLocalizedString("Tasmota Plugs", comment: "")
        default:
            fatalError("Unkonwn plugin")
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 1
    }
    
    // MARK: - OctoPrintPluginsDelegate
    
    func pluginMessage(plugin: String, data: NSDictionary) {
        if plugin == self.ipPlugPlugin {
            if let ip = data["ip"] as? String, let currentState = data["currentState"] as? String {
                var on: Bool?
                if currentState == "on" {
                    on = true
                } else if currentState == "off" {
                    on = false
                } else if currentState == "unknown" {
                    on = nil
                } else {
                    NSLog("Unknown plug state was found. ip: \(ip) state: \(currentState)")
                    return
                }
                // Track state for the plug
                plugsState[ip] = on
                // Refresh rows
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
        }
    }

    // MARK: - OctoPrintSettingsDelegate
    
    func ipPlugsChanged(plugin: String, plugs: Array<IPPlug>) {
        if ipPlugPlugin == plugin {
            self.plugs = plugs
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }

    // MARK: - Notifications from TPLinkSmartplugTableViewCell
    
    func powerPressed(cell: IPPlugTableViewCell) {
        if let on = cell.isPowerOn {
            let changePower = {
                if let indexPath = self.tableView.indexPath(for: cell) {
                    let plug = self.plugs[indexPath.row]
                    if Plugins.TP_LINK_SMARTPLUG == self.ipPlugPlugin {
                        self.octoprintClient.turnIPPlug(plugin: self.ipPlugPlugin, on: !on, plug: plug) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                            // If successfully requested then response is included in the response for this plugin (this changed recently)
                            if let dict = result as? NSDictionary {
                                self.pluginMessage(plugin: self.ipPlugPlugin, data: dict)
                            }
                            if response.statusCode >= 400 {
                                if let error = error {
                                    NSLog("Failed to request turn IP Plug with ip on/off: \(plug.ip). Error: \(error)")
                                } else {
                                    NSLog("Failed to request turn IP Plug with ip on/off: \(plug.ip). Response: \(response)")
                                }
                                let message = !on ? NSLocalizedString("Failed to request to turn power on", comment: "") : NSLocalizedString("Failed to request to turn power off", comment: "")
                                self.showAlert(NSLocalizedString("Warning", comment: ""), message: message)
                            }
                        }
                    } else {
                        self.octoprintClient.turnIPPlug(plugin: self.ipPlugPlugin, on: !on, plug: plug) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                            if !requested {
                                let message = !on ? NSLocalizedString("Failed to request to turn power on", comment: "") : NSLocalizedString("Failed to request to turn power off", comment: "")
                                self.showAlert(NSLocalizedString("Warning", comment: ""), message: message)
                            }
                        }
                    }
                }
            }
            if on {
                showConfirm(message: NSLocalizedString("Confirm turn off plug", comment: ""), yes: { (UIAlertAction) -> Void in
                    changePower()
                }, no: { (UIAlertAction) -> Void in
                    // Do nothing
                })
            } else {
                changePower()
            }
        }
    }

    // MARK: - Private functions
    
    fileprivate func refreshPlugs() {
        if let printer = printerManager.getDefaultPrinter() {
            switch ipPlugPlugin! {
            case Plugins.TP_LINK_SMARTPLUG:
                if let existingPlugs = printer.getTPLinkSmartplugs() {
                    plugs = existingPlugs
                } else {
                    plugs = []
                }
            case Plugins.WEMO_SWITCH:
                if let existingPlugs = printer.getWemoPlugs() {
                    plugs = existingPlugs
                } else {
                    plugs = []
                }
            case Plugins.DOMOTICZ:
                if let existingPlugs = printer.getDomoticzPlugs() {
                    plugs = existingPlugs
                } else {
                    plugs = []
                }
            case Plugins.TASMOTA:
                if let existingPlugs = printer.getTasmotaPlugs() {
                    plugs = existingPlugs
                } else {
                    plugs = []
                }
            default:
                fatalError("Unkonwn plugin")
            }
        } else {
            plugs = []
        }
    }
    
    fileprivate func checkPlugsState() {
        for plug in plugs {
            if Plugins.TP_LINK_SMARTPLUG == ipPlugPlugin {
                octoprintClient.checkIPPlugStatus(plugin: ipPlugPlugin, plug: plug) { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                    // If successfully requested then response is included in the response for this plugin (this changed recently)
                    if let dict = result as? NSDictionary {
                        self.pluginMessage(plugin: self.ipPlugPlugin, data: dict)
                    }
                    if let error = error {
                        NSLog("Failed to request state for IP Plug with ip: \(plug.ip). Error: \(error)")
                    }
                }
            } else {
                octoprintClient.checkIPPlugStatus(plugin: ipPlugPlugin, plug: plug) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                    // If successfully requested then response will come via websockets. OctoPrintPluginsDelegate will
                    // pick up the answer
                    if !requested {
                        NSLog("Failed to request state for IP Plug with ip: \(plug.ip)")
                    }
                }
            }
        }
    }

    fileprivate func showAlert(_ title: String, message: String) {
        UIUtils.showAlert(presenter: self, title: title, message: message, done: nil)
    }

    fileprivate func showConfirm(message: String, yes: @escaping (UIAlertAction) -> Void, no: @escaping (UIAlertAction) -> Void) {
        UIUtils.showConfirm(presenter: self, message: message, yes: yes, no: no)
    }
}
