import UIKit

class PrintersTableViewController: UITableViewController {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    
    var printers: [Printer]!

    override func viewDidLoad() {
        super.viewDidLoad()

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

        cell.textLabel?.text = printers[indexPath.row].name
        cell.detailTextLabel?.text = printers[indexPath.row].hostname

        return cell
    }

    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            printerManager.deletePrinter(printers[indexPath.row])
            printers = printerManager.getPrinters()
            tableView.reloadData()
        }    
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.performSegue(withIdentifier: "gotoPrinterDetails", sender: self)
    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        
        if segue.identifier == "gotoPrinterDetails" {
            if let printerDetailsController = segue.destination as? PrinterDetailsViewController {
                let selectedPrinter: Printer = printers[(tableView.indexPathForSelectedRow?.row)!]
                printerDetailsController.updatePrinter = selectedPrinter
            }
        }
    }
    
    @IBAction func unwindPrintersUpdated(_ sender: UIStoryboardSegue) {
        printers = printerManager.getPrinters()
        tableView.reloadData()
    }
}
