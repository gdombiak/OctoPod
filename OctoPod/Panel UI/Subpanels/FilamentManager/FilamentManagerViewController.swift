import UIKit

class FilamentManagerViewController : ThemedDynamicUITableViewController, SubpanelViewController, UIPopoverPresentationControllerDelegate, OctoPrintPluginsDelegate {
    
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()

    private var selections: Array<FilamentSelection> = []
    private var spools: Array<FilamentSpool> = []
    
    private var isPrinting = false

    override func viewDidLoad() {
        super.viewDidLoad()
    
        // Some bug in XCode Storyboards is not translating text of refresh control so let's do it manually
        self.refreshControl?.attributedTitle = NSAttributedString(string: NSLocalizedString("Pull down to refresh", comment: ""))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Fetch and render current filament selections
        refreshSelections(done: nil)

        // Listen to changes to OctoPrint Plugin messages
        octoprintClient.octoPrintPluginsDelegates.append(self)
        
        isPrinting = self.isPrinting(event: octoprintClient.lastKnownState)
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
        return selections.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Filament Manager"  // No need to translate name of plugin
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let selection = selections[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "selection_cell", for: indexPath) as! FilamentSelectionViewCell
        
        cell.parentVC = self

        // Configure the cell
        let currentTheme = Theme.currentTheme()

        cell.toolLabel.text = selection.displayTool()
        cell.toolLabel.textColor = currentTheme.textColor()
        
        cell.selectionButton.setTitle(selection.displaySelection(), for: .normal)
        cell.selectionButton.setTitleColor(Theme.currentTheme().tintColor(), for: .normal)
        cell.selectionButton.isEnabled = !self.isPrinting           // Diable button while printing
        cell.selectionButton.alpha = self.isPrinting ? 0.5 : 1.0    // Make it look disabled when printing
        
        cell.usageLabel.text = selection.displayRemaining()
        cell.usageLabel.textColor = currentTheme.textColor()

        return cell
    }
    
    // MARK: - Table view operations
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 36
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 1
    }

    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "change_selection", let controller = segue.destination as? FilamentChangeSelectionViewController, let cell = sender as? FilamentSelectionViewCell, let indexPath = self.tableView.indexPath(for: cell) {
            controller.popoverPresentationController!.delegate = self

            let selection = self.selections[indexPath.row]
            controller.toolNumber = selection.toolNumber
            controller.spools = spools
            
            // Make the popover appear at the middle of the button
            segue.destination.popoverPresentationController!.sourceView = cell.selectionButton
            segue.destination.popoverPresentationController!.sourceRect = CGRect(x: cell.selectionButton.frame.size.width/2, y: cell.selectionButton.frame.size.height/2 , width: 0, height: 0)
        }
    }

    // MARK: - Unwind operations
    
    @IBAction func backFromChangeSelection(_ sender: UIStoryboardSegue) {
        if let controller = sender.source as? FilamentChangeSelectionViewController {
            if let spoolId = controller.selectedSpool {
                octoprintClient.changeFilamentSelection(toolNumber: controller.toolNumber, spoolId: spoolId) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                    if requested {
                        self.refreshSelections(done: nil)
                    } else if let error = error {
                        // TODO Handle error
                        NSLog("Failed to change filament selection. Error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // MARK: - SubpanelViewController

    func printerSelectedChanged() {
        // Only refresh UI if view controller is being shown
        DispatchQueue.main.async {
            if let _ = self.parent {
                // Fetch and render current filament selections
                self.refreshSelections(done: nil)
            }
        }
    }
    
    func currentStateUpdated(event: CurrentStateEvent) {
        isPrinting = self.isPrinting(event: event)
        // Only refresh UI if view controller is being shown
        DispatchQueue.main.async {
            if let _ = self.parent {
                self.tableView.reloadData()
            }
        }
    }
    
    func position() -> Int {
        return 25
    }

    // MARK: - Notifications from Cells
    
    func openChangeSelection(cell: FilamentSelectionViewCell) {
        performSegue(withIdentifier: "change_selection", sender: cell)
    }
    
    // MARK: - OctoPrintPluginsDelegate
    
    func pluginMessage(plugin: String, data: NSDictionary) {
        if plugin == Plugins.FILAMENT_MANAGER {
            // Refresh status of outputs. Doing a new fetch is not the most
            // efficient way to do this but this is an infrequent operation
            // so it is good enough and we can reuse some code
            refreshSelections(done: nil)
        }
    }

    // MARK: - UIPopoverPresentationControllerDelegate
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }
    
    // We need to add this so it works on iPhone plus in landscape mode
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }
    
    // MARK: - Refresh
    
    @IBAction func refreshControls(_ sender: UIRefreshControl) {
        // Render outputs status
        refreshSelections(done: {
            DispatchQueue.main.async {
                sender.endRefreshing()
            }
        })
    }
    
    // MARK: - Private functions
    
    fileprivate func refreshSelections(done: (() -> Void)?) {
        octoprintClient.filamentSelections { (result: NSObject?, error: Error?, reponse: HTTPURLResponse) in
            self.selections = []
            if let error = error {
                self.showAlert(NSLocalizedString("Warning", comment: ""), message: error.localizedDescription, done: nil)
            } else if let json = result as? NSDictionary {
                if let selectionsArray = json["selections"] as? NSArray {
                    for case let selection as NSDictionary in selectionsArray {
                        let filamentSelection = FilamentSelection()
                        filamentSelection.parse(json: selection)
                        // Safety check that selections have specified a tool (no idea how plugin works - just in case)
                        if let _ = filamentSelection.toolNumber {
                            self.selections.append(filamentSelection)
                        }
                    }
                    // Sort selections by tool number
                    self.selections.sort { (left: FilamentSelection, right: FilamentSelection) -> Bool in
                        return left.toolNumber! < right.toolNumber!
                    }
                }
            }
            // Refresh table with new selections
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
            // Execute done block when done
            done?()
        }
        // Also refresh spools (they are used only when user clicks to change selection)
        octoprintClient.filamentSpools { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
            self.spools = []
            if let json = result as? NSDictionary {
                if let spoolsArray = json["spools"] as? NSArray {
                    for case let spool as NSDictionary in spoolsArray {
                        let filamentSpool = FilamentSpool()
                        filamentSpool.parse(json: spool)
                        // Safety check that selections have specified a tool (no idea how plugin works - just in case)
                        if let _ = filamentSpool.spoolId, let _ = filamentSpool.profileVendor, let _ = filamentSpool.profileMaterial {
                            self.spools.append(filamentSpool)
                        }
                    }
                    // Sort spools by vendor and material
                    self.spools.sort { (left: FilamentSpool, right: FilamentSpool) -> Bool in
                        return left.profileVendor! + left.profileMaterial! < right.profileVendor! + right.profileMaterial!
                    }
                }
            }
        }
    }
    
    /// Returns true if event indicates that we are printing. This is based on progress information
    fileprivate func isPrinting(event: CurrentStateEvent?) -> Bool {
        if let progress = event?.progressCompletion {
            return progress > 0 && progress < 100
        }
        return false
    }

    fileprivate func showAlert(_ title: String, message: String, done: (() -> Void)?) {
        UIUtils.showAlert(presenter: self, title: title, message: message, done: done)
    }
}
