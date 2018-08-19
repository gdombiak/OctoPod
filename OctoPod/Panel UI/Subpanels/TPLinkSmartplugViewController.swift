import UIKit

class TPLinkSmartplugViewController: ThemedDynamicUITableViewController, SubpanelViewController, OctoPrintSettingsDelegate, OctoPrintPluginsDelegate {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()

    var plugs: [Printer.TPLinkSmartplug] = []
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
        renderPrinter()
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
        // Get list of plugs for selected printer
        renderPrinter()
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    // Notification that OctoPrint state has changed. This may include printer status information
    func currentStateUpdated(event: CurrentStateEvent) {
        // Do nothing
    }
    
    // Returns the position where this VC should appear in SubpanelsViewController's UIPageViewController
    // SubpanelsViewController's will sort subpanels by this number when being displayed
    func position() -> Int {
        return 3
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return plugs.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "tplink_plug_cell", for: indexPath) as! TPLinkSmartplugTableViewCell
        let plug = plugs[indexPath.row]
        
        let label = cell.titleLabel
        label?.text = plug.label
        label?.textColor = Theme.currentTheme().labelColor()
        
        cell.ip = plug.ip
        
        let state: Bool? = plugsState[plug.ip]
        cell.setPowerState(isPowerOn: state)
        
        cell.parentVC = self
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "TPLink Smartplugs"
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }
    
    // MARK: - OctoPrintPluginsDelegate
    
    func pluginMessage(plugin: String, data: NSDictionary) {
        if plugin == "tplinksmartplug" {
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
    
    func tplinkSmartplugsChanged(plugs: Array<Printer.TPLinkSmartplug>) {
        self.plugs = plugs
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    // MARK: - Notifications from TPLinkSmartplugTableViewCell
    
    func powerPressed(cell: TPLinkSmartplugTableViewCell) {
        if let on = cell.isPowerOn {
            let changePower = {
                self.octoprintClient.turnTPLinkSmartplug(on: !on, ip: cell.ip) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                    if !requested {
                        self.showAlert("Warning", message: "Failed to request to turn power \(!on ? "on" : "off")")
                    }
                }
            }
            if on {
                showConfirm(message: "You are about to turn off the plug. Proceed?", yes: { (UIAlertAction) -> Void in
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
    
    fileprivate func renderPrinter() {
        if let printer = printerManager.getDefaultPrinter() {
            if let existingPlugs = printer.getTPLinkSmartplugs() {
                plugs = existingPlugs
            } else {
                plugs = []
            }
        } else {
            plugs = []
        }
    }
    
    fileprivate func checkPlugsState() {
        for plug in plugs {
            octoprintClient.checkTPLinkSmartplugStatus(ip: plug.ip) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                // If successfully requested then response will come via websockets. OctoPrintPluginsDelegate will
                // pick up the answer
                if !requested {
                    NSLog("Failed to request state for TPLink Smartplug with ip: \(plug.ip)")
                }
            }
        }
    }

    fileprivate func showAlert(_ title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: { (UIAlertAction) -> Void in
            // Nothing to do here
        }))
        // We are not on the main thread so present dialog on main thread to prevent crashes
        DispatchQueue.main.async {
            self.present(alert, animated: true) { () -> Void in
                // Nothing to do here
            }
        }
    }

    fileprivate func showConfirm(message: String, yes: @escaping (UIAlertAction) -> Void, no: @escaping (UIAlertAction) -> Void) {
        let alert = UIAlertController(title: "Confirm", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: yes))
        // Use default style and not cancel style for NO so it appears on the right
        alert.addAction(UIAlertAction(title: "No", style: .default, handler: no))
        self.present(alert, animated: true) { () -> Void in
            // Nothing to do here
        }
    }
}
