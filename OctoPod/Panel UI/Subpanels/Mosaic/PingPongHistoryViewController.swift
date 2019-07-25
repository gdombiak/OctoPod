import UIKit

class PingPongHistoryViewController: ThemedDynamicUITableViewController {

    var history: Array<Dictionary<String,Any>>?

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return history?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "history_cell", for: indexPath)

        // Configure the cell...
        if let entry = history?[indexPath.row], let messages = Palette2ViewController.pingPongMessage(entry: entry) {
            cell.textLabel?.text = "# " + messages.number
            cell.detailTextLabel?.text = messages.percent
        }

        return cell
    }
}
