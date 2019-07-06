import UIKit

class PluginUpdatesViewController: UIViewController, UITableViewDataSource {
    
    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let pluginUpdatesManager: PluginUpdatesManager = { return (UIApplication.shared.delegate as! AppDelegate).pluginUpdatesManager }()

    var availableUpdates: Array<PluginUpdatesManager.UpdateAvailable>?

    @IBOutlet weak var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // MARK: - Table view data source

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return availableUpdates?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return NSLocalizedString("Update Available", comment: "Title for window that alerts user that updates for plugins are available")
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "updateAvailable", for: indexPath)

        // Configure the cell...
        cell.textLabel?.text = availableUpdates![indexPath.row].pluginName
        cell.detailTextLabel?.text = availableUpdates![indexPath.row].version

        return cell
    }
    
    @IBAction func dismissClicked(_ sender: Any) {
        // Close window
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func ignoreClicked(_ sender: Any) {
        // Snooze alerts for this specific update and printer
        if let printer = printerManager.getDefaultPrinter(), let updates = availableUpdates {
            pluginUpdatesManager.snoozeUpdatesFor(printer: printer, updatesAvailable: updates)
        }
        // Close window
        self.dismiss(animated: true, completion: nil)
    }
}
