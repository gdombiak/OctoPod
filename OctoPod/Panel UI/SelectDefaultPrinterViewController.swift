import UIKit

class SelectDefaultPrinterViewController: UITableViewController {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    
    var printers: [Printer]!
    var onCompletion: (()->Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        printers = printerManager.getPrinters()
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

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        printerManager.changeToDefaultPrinter(printers[indexPath.row])
        dismiss(animated: true, completion: onCompletion)

    }
}
