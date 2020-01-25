import UIKit

class SelectDefaultPrinterViewController: ThemedDynamicUITableViewController {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let watchSessionManager: WatchSessionManager = { return (UIApplication.shared.delegate as! AppDelegate).watchSessionManager }()

    var printers: [Printer]!
    var onCompletion: (()->Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        printers = printerManager.getPrinters()

        // Set background color of popover and its arrow based on current theme
        let theme = Theme.currentTheme()
        self.popoverPresentationController?.backgroundColor = theme.backgroundColor()
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
        return printers.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "printerCell", for: indexPath)

        cell.textLabel?.text = printers[indexPath.row].name // + (printers[indexPath.row].defaultPrinter ? " (Active)" : "")
        cell.detailTextLabel?.text = printers[indexPath.row].hostname
        // Show a checkmark next to active printer
        cell.accessoryType = printers[indexPath.row].defaultPrinter ? .checkmark : .none

        // Theme color of labels
        let theme = Theme.currentTheme()
        cell.textLabel?.textColor = theme.textColor()
        cell.detailTextLabel?.textColor = theme.textColor()

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        printerManager.changeToDefaultPrinter(printers[indexPath.row])
        // Update Apple Watch with new selected printer
        watchSessionManager.pushPrinters()
        dismiss(animated: true, completion: onCompletion)
    }
}
