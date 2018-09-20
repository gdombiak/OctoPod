import UIKit

class DevicesSyncLogViewController: ThemedDynamicUITableViewController, CloudKitPrinterLogDelegate {

    let cloudKitPrinterManager: CloudKitPrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).cloudKitPrinterManager }()
    
    let dateFormatter: DateFormatter = DateFormatter()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Format date formatter
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Listen to changes to the log
        cloudKitPrinterManager.logDelegates.append(self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Stop listening to changes to the log
        cloudKitPrinterManager.remove(cloudKitPrinterLogDelegate: self)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cloudKitPrinterManager.log.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "log_entry_cell", for: indexPath)

        let logEntry = cloudKitPrinterManager.log[indexPath.row]
        cell.textLabel?.text = logEntry.description
        cell.detailTextLabel?.text = dateFormatter.string(from: logEntry.date)
        
        // Resize text label since entry length is variable
        cell.textLabel?.sizeToFit()

        return cell
    }
    
    // MARK: - CloudKitPrinterLogDelegate
    
    func logUpdated(newEntry: CloudKitPrinterLogEntry) {
        DispatchQueue.main.async {
            // Refresh table
            self.tableView.reloadData()
        }
    }
}
