import UIKit

class SystemCommandsViewController: ThemedDynamicUITableViewController, SubpanelViewController  {

    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()

    var commands: Array<SystemCommand>?

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

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

    // Notification that another OctoPrint server has been selected
    func printerSelectedChanged() {
        // Fetch and render system commands
        refreshSystemCommands(done: nil)
    }
    
    // Notification that OctoPrint state has changed. This may include printer status information
    func currentStateUpdated(event: CurrentStateEvent) {
        // Do nothing
    }
    
    // Returns the position where this VC should appear in SubpanelsViewController's UIPageViewController
    // SubpanelsViewController's will sort subpanels by this number when being displayed
    func position() -> Int {
        return 6
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
}
