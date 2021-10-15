import UIKit
import SafariServices  // Used for opening browser in-app

class CustomControlsViewController: ThemedDynamicUITableViewController, SubpanelViewController {

    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()

    @IBOutlet weak var footerView: UIView!
    
    var containers: Array<Container>?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Theme footer
        let theme = Theme.currentTheme()
        footerView.backgroundColor = theme.cellBackgroundColor()
        // Set color (and text) to refresh control
        if let refreshControl = refreshControl {
            ThemeUIUtils.applyTheme(refreshControl: refreshControl)
        }

        // Hide footer. Will appear only if no custom controls were found
        footerView.isHidden = true
        
        // Fetch and render custom controls
        refreshCustomControls(done: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return containers == nil ? 0 : containers!.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return NSLocalizedString("Custom Controls", comment: "http://docs.octoprint.org/en/master/features/custom_controls.html")
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 36
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return footerView.isHidden ? 1 : 50
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "container_cell", for: indexPath)

        // Configure the cell
        if let containersArray = containers {
            cell.textLabel?.text = containersArray[indexPath.row].name()
            cell.textLabel?.textColor = Theme.currentTheme().labelColor()
        }

        return cell
    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "gotoChildren" {
            if let controller = segue.destination as? ChildrenCustomControlViewController, let selected = tableView.indexPathForSelectedRow, let allContainers = containers {
                controller.rootControlsVC = self
                controller.container = allContainers[selected.row]
            }
        }
    }
    
    // MARK: - SubpanelViewController

    func printerSelectedChanged() {
        // Only refresh UI if view controller is being shown
        DispatchQueue.main.async {
            if let _ = self.parent {
                // Fetch and render custom controls
                self.refreshCustomControls(done: nil)
            }
        }
    }
    
    func currentStateUpdated(event: CurrentStateEvent) {
        // Do nothing
    }
    
    func position() -> Int {
        return 50
    }
    
    // MARK: - Unwind operations

    @IBAction func gobackToRootFolder(_ sender: UIStoryboardSegue) {
        // Containers have been refreshed so just update UI
        self.tableView.reloadData()
    }
    
    // MARK: - Button operations
    
    @IBAction func clickedOnLearnMore(_ sender: Any) {
        let svc = SFSafariViewController(url: URL(string: "http://docs.octoprint.org/en/master/features/custom_controls.html")!)
        self.present(svc, animated: true, completion: nil)
    }
    
    @IBAction func clickedOnUsePlugin(_ sender: Any) {
        let svc = SFSafariViewController(url: URL(string: "https://plugins.octoprint.org/plugins/customControl")!)
        self.present(svc, animated: true, completion: nil)
    }
    
    // MARK: - Refresh

    @IBAction func refreshControls(_ sender: UIRefreshControl) {
        // Fetch and render custom controls
        refreshCustomControls(done: {
            DispatchQueue.main.async {
                sender.endRefreshing()
            }
        })
    }
    
    // Refresh custom controls from OctoPrint and call me back with the refreshed container that was specified (if found)
    func refreshContainer(container: Container, callback: @escaping ((Container?) -> Void)) {
        refreshCustomControls(done: {
            if let allContainers = self.containers {
                for rootContainer in allContainers {
                    if let found = rootContainer.locate(container: container) {
                        callback(found)
                        return
                    }
                }
            }
            // Could happen if folder no longer exists
            callback(nil)
        })
    }

    // MARK: - Private functions
    
    fileprivate func refreshCustomControls(done: (() -> Void)?) {
        octoprintClient.customControls { (containers: Array<Container>?, error: Error?, response: HTTPURLResponse) in
            self.containers = containers
            let show = self.containers == nil || self.containers!.isEmpty  // Show footer only if there are no custom controls defined
            DispatchQueue.main.async {
                if self.footerView != nil {
                    // We might not be initialized yet so need to protect from this
                    self.footerView.isHidden = !show
                }
                self.tableView.reloadData()
            }
            if let _ = error {
                self.showAlert(NSLocalizedString("Warning", comment: ""), message: error!.localizedDescription)
            } else if response.statusCode != 200 {
                self.showAlert(NSLocalizedString("Warning", comment: ""), message: String(format: NSLocalizedString("Failed to get controls", comment: "Failed to get controls with HTTP Request error info"), response.statusCode))
            }
            // Execute done block when done
            done?()
        }
    }
    
    fileprivate func showAlert(_ title: String, message: String) {
        UIUtils.showAlert(presenter: self, title: title, message: message, done: nil)
    }
}
