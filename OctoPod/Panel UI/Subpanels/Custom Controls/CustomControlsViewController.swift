import UIKit

class CustomControlsViewController: ThemedDynamicUITableViewController, SubpanelViewController {

    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()

    var containers: Array<Container>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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
        return "Custom Controls"
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
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
        // Fetch and render custom controls
        refreshCustomControls(done: nil)
    }
    
    // Notification that OctoPrint state has changed. This may include printer status information
    func currentStateUpdated(event: CurrentStateEvent) {
        // Do nothing
    }
    
    // Returns the position where this VC should appear in SubpanelsViewController's UIPageViewController
    // SubpanelsViewController's will sort subpanels by this number when being displayed
    func position() -> Int {
        return 2
    }
    
    // MARK: - Unwind operations

    @IBAction func gobackToRootFolder(_ sender: UIStoryboardSegue) {
        // Containers have been refreshed so just update UI
        self.tableView.reloadData()
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
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
            if let _ = error {
                self.showAlert("Warning", message: error!.localizedDescription)
            } else if response.statusCode != 200 {
                self.showAlert("Warning", message: "Failed to get controls. HTTP response: \(response.statusCode)")
            }
            // Execute done block when done
            done?()
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
}
