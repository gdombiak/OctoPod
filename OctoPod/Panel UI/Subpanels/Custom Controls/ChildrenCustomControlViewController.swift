import UIKit

class ChildrenCustomControlViewController: ThemedDynamicUITableViewController {

    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()

    var rootControlsVC: CustomControlsViewController!
    var container: Container!
    var childrenCC: Array<CustomControl>!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Update window title to folder we are browsing
        navigationItem.title = container.name()
        
        childrenCC = container.children
        // Reload and repaint things
        tableView.reloadData()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return childrenCC!.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if let container = childrenCC[indexPath.row] as? Container {
            let cell = tableView.dequeueReusableCell(withIdentifier: "container_cell", for: indexPath)
            // Configure the cell
            cell.textLabel?.text = container.name()
            cell.textLabel?.textColor = Theme.currentTheme().labelColor()
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "control_cell", for: indexPath) as! CustomControlViewCell
            cell.textLabel?.text = nil  // Clean up unused label
            cell.runButton.isEnabled = !appConfiguration.appLocked()
            // Configure the cell
            if let command = childrenCC[indexPath.row] as? Command {
                cell.imageView?.image = UIImage(named: "GCode")
                cell.nameLabel.text = command.name()
                cell.nameLabel.textColor = Theme.currentTheme().labelColor()
            } else if let script = childrenCC[indexPath.row] as? Script {
                cell.imageView?.image = UIImage(named: "Script")
                cell.nameLabel.text = script.name()
                cell.nameLabel.textColor = Theme.currentTheme().labelColor()
            } else {
                NSLog("Found unexpected custom control: \(childrenCC[indexPath.row])")
                cell.imageView?.image = nil
                cell.nameLabel.text = NSLocalizedString("Unknown Control", comment: "Unknown Custom Control")
            }
            return cell
        }
    }

    @IBAction func executeCommand(_ sender: UIButton) {
        let buttonPosition = sender.convert(CGPoint.zero, to: tableView)
        if let indexPath: IndexPath = tableView.indexPathForRow(at: buttonPosition), let control = childrenCC[indexPath.row] as? ExecuteControl {
            // Check if control requires user input
            if let input = control.input(), !input.isEmpty {
                // Select the row before going to the page. This is needed by #prepare(for segue: UIStoryboardSegue, sender: Any?) 
                tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
                self.performSegue(withIdentifier: "gotoControl", sender: self)
            } else {
                let executeBlock = {
                    let json = control.executePayload()
                    self.octoprintClient.executeCustomControl(control: json, callback: { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                        if !requested {
                            // Handle error
                            NSLog("Error requesting to execute command \(json). HTTP status code \(response.statusCode)")
                            if response.statusCode == 409 {
                                self.showAlert(NSLocalizedString("Warning", comment: ""), message: NSLocalizedString("Command not executed. Printer not operational", comment: ""))
                            } else if response.statusCode == 404 {
                                self.showAlert(NSLocalizedString("Warning", comment: ""), message: NSLocalizedString("Command not executed. Script not found", comment: ""))
                            } else {
                                self.showAlert(NSLocalizedString("Warning", comment: ""), message: NSLocalizedString("Failed to request to execute command", comment: ""))
                            }
                        }
                    })
                }
                if let confirmMsg = control.confirm(), !confirmMsg.isEmpty {
                    // Show confirmation message before excuting command
                    showConfirm(message: confirmMsg, yes: { (alert: UIAlertAction) in
                        executeBlock()
                    }) { (alert: UIAlertAction) in
                        // Do nothing
                    }
                } else {
                    // Execute command without confirmation message
                    executeBlock()
                }
            }
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "gotoControl" {
            if let controller = segue.destination as? ExecuteControlViewController, let selected = tableView.indexPathForSelectedRow {
                if let executeControl = childrenCC[selected.row] as? ExecuteControl {
                    controller.control = executeControl
                }
            }
        } else if segue.identifier == "gotoContainer" {
            if let controller = segue.destination as? ChildrenCustomControlViewController, let selected = tableView.indexPathForSelectedRow {
                if let childContainer = childrenCC[selected.row] as? Container {
                    controller.rootControlsVC = rootControlsVC
                    controller.container = childContainer
                }
            }
        }
    }

    @IBAction func refreshControls(_ sender: UIRefreshControl) {
        rootControlsVC.refreshContainer(container: container) { (updatedContainer: Container?) in
            if let updated = updatedContainer {
                self.container = updated
                self.childrenCC = updated.children
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                    sender.endRefreshing()
                }
            } else {
                // Go back to root folder since folder no longer exists
                DispatchQueue.main.async {
                    self.performSegue(withIdentifier: "gobackToRootFolder", sender: self)
                }
            }
        }
    }

    // MARK: - Private functions
    
    fileprivate func showAlert(_ title: String, message: String) {
        UIUtils.showAlert(presenter: self, title: title, message: message, done: nil)
    }
    
    fileprivate func showConfirm(message: String, yes: @escaping (UIAlertAction) -> Void, no: @escaping (UIAlertAction) -> Void) {
        UIUtils.showConfirm(presenter: self, message: message, yes: yes, no: no)
    }
}
