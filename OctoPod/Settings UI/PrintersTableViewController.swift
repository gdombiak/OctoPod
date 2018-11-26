import UIKit

class PrintersTableViewController: ThemedDynamicUITableViewController, CloudKitPrinterDelegate {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let cloudKitPrinterManager: CloudKitPrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).cloudKitPrinterManager }()
    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()
    let watchSessionManager: WatchSessionManager = { return (UIApplication.shared.delegate as! AppDelegate).watchSessionManager }()

    var printers: [Printer]!

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Get list of printers
        printers = printerManager.getPrinters()

        // Listen to events when printers get updated from iCloud information
        cloudKitPrinterManager.delegates.append(self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Stop listening to events when printers get updated from iCloud information
        cloudKitPrinterManager.remove(cloudKitPrinterDelegate: self)
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

    // Delete is only available if app is not in read-only mode
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return !appConfiguration.appLocked()
    }
    
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let printerToDelete = printers[indexPath.row]
            // Update other devices via CloudKit
            self.cloudKitPrinterManager.pushDeletedPrinter(printer: printerToDelete)  // Properties are gone once deleted from Core Data so run this now
            
            // Delete Siri suggestions (user will need to manually delete recorded Shortcuts)
            IntentsDonations.deletePrinterIntents(printer: printerToDelete)

            // Delete the row from the data source
            printerManager.deletePrinter(printerToDelete)
            printers = printerManager.getPrinters()

            // Push changes to Apple Watch
            self.watchSessionManager.pushPrinters()

            // Refresh UI table
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
    
    // MARK: - CloudKitPrinterDelegate
    
    func printersUpdated() {
        DispatchQueue.main.async {
            // Get new printers
            self.printers = self.printerManager.getPrinters()
            // Refresh table of printers
            self.tableView.reloadData()
        }
    }
    
    func printerAdded(printer: Printer) {
        // Do nothing. We will process things on #printersUpdated
    }
    
    func printerUpdated(printer: Printer) {
        // Do nothing. We will process things on #printersUpdated
    }
    
    func printerDeleted(printer: Printer) {
        // Do nothing. We will process things on #printersUpdated
    }
}
