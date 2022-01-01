import UIKit
import AVFoundation

class OctorelayViewController: ThemedDynamicUITableViewController, SubpanelViewController, OctoPrintPluginsDelegate {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()
    
    var octorelay: [Octorelay] = []
    var plugsState: Dictionary<String, Bool> = Dictionary()
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let refreshControl = refreshControl {
            ThemeUIUtils.applyTheme(refreshControl: refreshControl)
        }

        // Fetch and render custom controls
        refreshRelays(done: nil)

        // Listen to changes to OctoPrint Plugin messages
        octoprintClient.octoPrintPluginsDelegates.append(self)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Stop listening to changes to OctoPrint Plugin messages
        octoprintClient.remove(octoPrintPluginsDelegate: self)
    }

    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return octorelay.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return NSLocalizedString("Octorelay", comment: "https://github.com/bastienstefani/OctoRelay")
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 36
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "octorelay_cell", for: indexPath) as! OctorelayViewCell
        
        // Configure the cell
        let relay = octorelay[indexPath.row]
        cell.id =  relay.id
        cell.parentVC = self
        
        cell.titleLabel?.text = octorelay[indexPath.row].name
        cell.titleLabel?.textColor = Theme.currentTheme().labelColor()
        
        let state = relay.active
        cell.setPowerState(isPowerOn: state)
        cell.powerButton.isEnabled = !appConfiguration.appLocked()
        
        return cell
    }

    // MARK: - SubpanelViewController
    
    func printerSelectedChanged() {
        // Only refresh UI if view controller is being shown
        DispatchQueue.main.async {
            if let _ = self.parent {
                // Fetch and render list of objects that can be cancelled
                self.refreshRelays(done: nil)
            }
        }
    }
    
    func currentStateUpdated(event: CurrentStateEvent) {
        // Do nothing
    }
    
    func position() -> Int {
        return 20
    }
    
    func getRelay(relayId : String) -> Octorelay? {
        for relay in octorelay {
            if relay.id == relayId {
                return relay
            }
        }
        return nil
    }

    // MARK: - Button operations

    func toggleRelay(objectId: String) {
        self.octoprintClient.switchRelay(id: objectId) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
            if requested {
                // Fetch and refresh UI
                self.refreshRelays(done: nil)
            } else if let _ = error {
                self.showAlert(NSLocalizedString("Warning", comment: ""), message: error!.localizedDescription)
            } else if response.statusCode != 200 {
                self.showAlert(NSLocalizedString("Warning", comment: ""), message: String(format: NSLocalizedString("Failed to request relay switch", comment: ""), response.statusCode))
            }
        }
    }
    
    // MARK: - OctoPrintPluginsDelegate
    
    func pluginMessage(plugin: String, data: NSDictionary) {
        if plugin == Plugins.OCTO_RELAY {
            // We cannot use provided data since it is not the same data returned
            // from API that is needed for switching relays on/off
            // Fetch and render custom controls
            refreshRelays(done: nil)
        }
    }

    // MARK: - Refresh
    
    @IBAction func refreshControls(_ sender: UIRefreshControl) {
        // Fetch and render custom controls
        refreshRelays(done: {
            DispatchQueue.main.async {
                sender.endRefreshing()
            }
        })
    }
    
    // MARK: - Private functions
    
    fileprivate func refreshRelays(done: (() -> Void)?) {
        octoprintClient.getOctorelays { (relays: Array<Octorelay>?, error: Error?, response: HTTPURLResponse) in
            DispatchQueue.main.async {
                if let objects = relays {
                    self.octorelay = objects
                } else {
                    self.octorelay = []
                }
                self.tableView.reloadData()
            }
            if let _ = error {
                self.showAlert(NSLocalizedString("Warning", comment: ""), message: error!.localizedDescription)
            } else if response.statusCode != 200 {
                self.showAlert(NSLocalizedString("Warning", comment: ""), message: String(format: NSLocalizedString("Failed to get list of relays", comment: ""), response.statusCode))
            }
            // Execute done block when done
            done?()
        }
    }
    
    fileprivate func showAlert(_ title: String, message: String) {
        UIUtils.showAlert(presenter: self, title: title, message: message, done: nil)
    }

    fileprivate func showConfirm(message: String, yes: @escaping (UIAlertAction) -> Void, no: @escaping (UIAlertAction) -> Void) {
        UIUtils.showConfirm(presenter: self, message: message, yes: yes, no: no)
    }
}
