import UIKit

class ChildrenCustomControlViewController: ThemedDynamicUITableViewController {

    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    
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
            let cell = tableView.dequeueReusableCell(withIdentifier: "control_cell", for: indexPath)
            // Configure the cell
            if let command = childrenCC[indexPath.row] as? Command {
                cell.imageView?.image = UIImage(named: "GCode")
                cell.textLabel?.text = command.name()
                cell.textLabel?.textColor = Theme.currentTheme().labelColor()
            } else if let script = childrenCC[indexPath.row] as? Script {
                cell.imageView?.image = UIImage(named: "Script")
                cell.textLabel?.text = script.name()
                cell.textLabel?.textColor = Theme.currentTheme().labelColor()
            } else {
                NSLog("Found unexpected custom control: \(childrenCC[indexPath.row])")
                cell.imageView?.image = nil
                cell.textLabel?.text = NSLocalizedString("Unknown Control", comment: "Unknown Custom Control")
            }
            return cell
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
}
