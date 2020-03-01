import UIKit

class PrintersTableViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, CloudKitPrinterDelegate {

    private var currentTheme: Theme.ThemeChoice!

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let cloudKitPrinterManager: CloudKitPrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).cloudKitPrinterManager }()
    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()
    let watchSessionManager: WatchSessionManager = { return (UIApplication.shared.delegate as! AppDelegate).watchSessionManager }()

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var reorderButton: UIButton!
    
    var printers: [Printer]!

    private var myReorderImage: UIImage? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Remember current theme so we know when to repaint
        currentTheme = Theme.currentTheme()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if currentTheme != Theme.currentTheme() {
            // Theme changed so repaint table now (to prevent quick flash in the UI with the old theme)
            tableView.reloadData()
            currentTheme = Theme.currentTheme()
        }
        // Paint UI based on theme
        ThemeUIUtils.applyTheme(table: tableView, staticCells: false)
        // Set background color to the view
        view.backgroundColor = currentTheme.backgroundColor()

        // Get list of printers
        printers = printerManager.getPrinters()

        // Listen to events when printers get updated from iCloud information
        cloudKitPrinterManager.delegates.append(self)

        // Disable editing mode so that printers cannot be reordered
        tableView.isEditing = false
        
        reorderButton.isEnabled = !appConfiguration.appLocked()
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

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return printers.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "printerCell", for: indexPath)

        cell.textLabel?.text = printers[indexPath.row].name
        cell.detailTextLabel?.text = printers[indexPath.row].hostname

        return cell
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        ThemeUIUtils.themeCell(cell: cell)
        
        // Check if we need to change the color of the 3 bars to reorder printers
        if tableView.isEditing {
            let theme = Theme.currentTheme()
            if theme == Theme.ThemeChoice.Dark || theme == Theme.ThemeChoice.Orange {
                for subViewA in cell.subviews {
                    if (subViewA.classForCoder.description() == "UITableViewCellReorderControl") {
                        for subViewB in subViewA.subviews {
                            if (subViewB.isKind(of: UIImageView.classForCoder())) {
                                let imageView = subViewB as! UIImageView;
                                if (myReorderImage == nil) {
                                    let myImage = imageView.image;
                                    myReorderImage = myImage?.withRenderingMode(UIImage.RenderingMode.alwaysTemplate);
                                }
                                imageView.image = myReorderImage;
                                imageView.tintColor = UIColor.white;
                                break;
                            }
                        }
                        break;
                    }
                }
            }
        }
    }

    // Delete is only available if app is not in read-only mode
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return !appConfiguration.appLocked()
    }
    
    // Override to support editing the table view.
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let printerToDelete = printers[indexPath.row]
            // Update other devices via CloudKit
            self.cloudKitPrinterManager.pushDeletedPrinter(printer: printerToDelete)  // Properties are gone once deleted from Core Data so run this now
            
            // Delete Siri suggestions (user will need to manually delete recorded Shortcuts)
            IntentsDonations.deletePrinterIntents(printer: printerToDelete)

            // Delete the row from the data source
            printerManager.deletePrinter(printerToDelete, context: printerManager.managedObjectContext!)
            printers = printerManager.getPrinters()

            // Push changes to Apple Watch
            self.watchSessionManager.pushPrinters()

            // Refresh UI table
            tableView.reloadData()
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.performSegue(withIdentifier: "gotoPrinterDetails", sender: self)
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return tableView.isEditing ? .none : .delete
    }
    
    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return !appConfiguration.appLocked()
    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        // Reorder array of printers
        let toMove = printers.remove(at: sourceIndexPath.row)
        printers.insert(toMove, at: destinationIndexPath.row)
        // Store new ordered printers
        NSLog("Storing new printers order")
        for (index, printer) in printers.enumerated() {
            let newObjectContext = printerManager.newPrivateContext()
            let printerToUpdate = newObjectContext.object(with: printer.objectID) as! Printer
            // Update printer position
            printerToUpdate.position = Int16(index)
            // Persist updated printer
            printerManager.updatePrinter(printerToUpdate, context: newObjectContext)
        }
        // Push changes to Apple Watch
        self.watchSessionManager.pushPrinters()
    }

    // MARK: - Buttons

    @IBAction func reorderClicked(_ sender: Any) {
        // Enable or disable editing mode so that printers can be reordered
        tableView.isEditing = !tableView.isEditing
        
        tableView.reloadData()
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
        } else if segue.identifier == "addNewPrinter" {
            if let printerDetailsController = segue.destination as? PrinterDetailsViewController {
                printerDetailsController.newPrinterPosition = Int16(printers.count)
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

    func iCloudStatusChanged(connected: Bool) {
    }
}
