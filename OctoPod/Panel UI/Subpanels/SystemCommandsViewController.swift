import UIKit

class SystemCommandsViewController: ThemedDynamicUITableViewController, SubpanelViewController  {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()

    var commands: Array<SystemCommand>?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set color (and text) to refresh control
        if let refreshControl = refreshControl {
            ThemeUIUtils.applyTheme(refreshControl: refreshControl)
        }

        // Fetch and render system commands
        refreshSystemCommands(done: nil)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return commands == nil ? 0 : commands!.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return NSLocalizedString("System Commands", comment: "http://docs.octoprint.org/en/master/api/system.html")
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "command_cell", for: indexPath)

        // Configure the cell
        if let commandsArray = commands {
            cell.textLabel?.text = commandsArray[indexPath.row].name
        } else {
            cell.textLabel?.text = nil
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Deselect table row to show nice effect and not leave row selected in the UI
        tableView.deselectRow(at: indexPath, animated: true)
        if appConfiguration.appLocked() {
            // Do nothing if app is locked
            return
        }
        if let command = commands?[indexPath.row] {
            // Prompt for confirmation that we want to disconnect from printer
            showConfirm(message: String(format: NSLocalizedString("Confirm command", comment: ""), command.name), yes: { (UIAlertAction) -> Void in
                let generator = UINotificationFeedbackGenerator()
                generator.prepare()
                self.octoprintClient.executeSystemCommand(command: command, callback: { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                    if requested {
                        DispatchQueue.main.async {
                            generator.notificationOccurred(.success)
                        }
                    } else {
                        // Handle error
                        NSLog("Error executing system command. HTTP status code \(response.statusCode)")
                        self.showAlert(NSLocalizedString("Warning", comment: ""), message: NSLocalizedString("Failed to request to execute command", comment: ""))

                    }
                })
            }, no: { (UIAlertAction) -> Void in
                // Do nothing
            })
            // Donate System Command to Siri
            if let printer = printerManager.getDefaultPrinter() {
                    IntentsDonations.donateSystemCommand(printer: printer, action: command.action, source: command.source, name: command.name)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        return appConfiguration.appLocked() ? nil : indexPath
    }

    // MARK: - Table view operations
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 36
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 1
    }

    // MARK: - Refresh
    
    @IBAction func refreshControls(_ sender: UIRefreshControl) {
        // Fetch and render custom controls
        refreshSystemCommands(done: {
            DispatchQueue.main.async {
                sender.endRefreshing()
            }
        })
    }
    
    // MARK: - SubpanelViewController

    func printerSelectedChanged() {
        // Only refresh UI if view controller is being shown
        DispatchQueue.main.async {
            if let _ = self.parent {
                // Fetch and render system commands
                self.refreshSystemCommands(done: nil)
            }
        }
    }
    
    func currentStateUpdated(event: CurrentStateEvent) {
        // Do nothing
    }
    
    func position() -> Int {
        return 60
    }

    // MARK: - Private functions
    
    fileprivate func refreshSystemCommands(done: (() -> Void)?) {
        octoprintClient.systemCommands { (commands: Array<SystemCommand>?, error: Error?, response: HTTPURLResponse) in
            self.commands = commands
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
            if let _ = error {
                self.showAlert(NSLocalizedString("Warning", comment: ""), message: error!.localizedDescription)
            } else if response.statusCode != 200 {
                self.showAlert(NSLocalizedString("Warning", comment: ""), message: String(format: NSLocalizedString("Failed to get system commands", comment: "Failed to get system commands with HTTP Request error info"), response.statusCode))
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
