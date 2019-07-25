import UIKit

class Palette2PortsViewController: ThemedDynamicUITableViewController, OctoPrintPluginsDelegate {

    var ports: Array<String>?
    var selectedPort: String?
    
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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
        return ports?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "palette_port", for: indexPath)

        // Configure the cell...
        if let ports = ports {
            cell.textLabel?.text = ports[indexPath.row]
            // Show a checkmark next to default port
            cell.accessoryType = ports[indexPath.row] == selectedPort ? .checkmark : .none
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Update selected port
        selectedPort = ports?[indexPath.row]
        // Close window
        dismiss(animated: true, completion: nil)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    // MARK: - OctoPrintPluginsDelegate
    
    func pluginMessage(plugin: String, data: NSDictionary) {
        if plugin == Plugins.PALETTE_2 {
            if let command = data["command"] as? String {
                if command == "ports", let ports = data["data"] as? Array<String> {
                    // Available ports on server where OctoPrint runs
                    self.ports = ports
                    // Refresh UI
                    DispatchQueue.main.async {
                        self.tableView.reloadData()
                    }
                } else if command == "selectedPort", let port = data["data"] as? String {
                    // Current port being used by OctoPrint server to connect to Palette 2
                    selectedPort = port
                    // Refresh UI
                    DispatchQueue.main.async {
                        self.tableView.reloadData()
                    }
                }
            }
        }
    }

    // MARK: - Private functions
    
    fileprivate func refreshPorts(done: (() -> Void)?) {
        octoprintClient.palette2Ports { (requested: Bool, error: Error?, response: HTTPURLResponse) in
            // TODO: Implement alert error
        }
    }
}
