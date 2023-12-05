import UIKit

class SpoolManagerViewController : ThemedDynamicUITableViewController, SubpanelViewController, UIPopoverPresentationControllerDelegate, OctoPrintPluginsDelegate {
    
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()

    private var selections: Array<SpoolSelection> = []
    private var spools: Array<Spool> = []
    
    private var isPrinting = false

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set color (and text) to refresh control
        if let refreshControl = refreshControl {
            ThemeUIUtils.applyTheme(refreshControl: refreshControl)
        }

        // Fetch and render current spool selections
        refreshSelections(done: nil)

        // Listen to changes to OctoPrint Plugin messages
        octoprintClient.octoPrintPluginsDelegates.append(self)
        
        isPrinting = PrinterUtils.isPrinting(event: octoprintClient.lastKnownState)
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
        return "Spool Manager"  // No need to translate name of plugin
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let selection = selections[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "selection_cell", for: indexPath) as! SpoolSelectionViewCell
        
        cell.parentVC = self

        // Configure the cell
        let currentTheme = Theme.currentTheme()

        cell.toolLabel.text = selection.displayTool()
        cell.toolLabel.textColor = currentTheme.textColor()
        
        cell.selectionButton.setTitle(selection.displaySelection(), for: .normal)
        cell.selectionButton.setTitleColor(Theme.currentTheme().tintColor(), for: .normal)
        cell.selectionButton.isEnabled = !self.isPrinting           // Disable button while printing
        cell.selectionButton.alpha = self.isPrinting ? 0.5 : 1.0    // Make it look disabled when printing
        
        cell.usageLabel.text = selection.displayRemaining()
        cell.usageLabel.textColor = currentTheme.textColor()
        
        cell.codeLabel.text = selection.displayCode()
        cell.codeLabel.textColor = currentTheme.textColor()

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
        if segue.identifier == "change_selection", let controller = segue.destination as? SpoolChangeSelectionViewController, let cell = sender as? SpoolSelectionViewCell, let indexPath = self.tableView.indexPath(for: cell) {
            controller.popoverPresentationController!.delegate = self

            let selection = self.selections[indexPath.row]
            controller.toolNumber = selection.toolNumber
            controller.currentSpool = selection.spoolId
            controller.spools = spools
            
            // Make the popover appear at the middle of the button
            segue.destination.popoverPresentationController!.sourceView = cell.selectionButton
            segue.destination.popoverPresentationController!.sourceRect = CGRect(x: cell.selectionButton.frame.size.width/2, y: cell.selectionButton.frame.size.height/2 , width: 0, height: 0)
        }
    }

    // MARK: - Unwind operations
    
    @IBAction func backFromChangeSelection(_ sender: UIStoryboardSegue) {
        if let controller = sender.source as? SpoolChangeSelectionViewController {
            if let spoolId = controller.selectedSpool {
                octoprintClient.changeSpoolSelection(toolNumber: controller.toolNumber, spoolId: spoolId) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                    if requested {
                        self.refreshSelections(done: nil)
                    } else if let error = error {
                        // TODO Handle error
                        NSLog("Failed to change spool selection. Error: \(error.localizedDescription)")
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
                // Fetch and render current spool selections
                self.refreshSelections(done: nil)
            }
        }
    }
    
    func currentStateUpdated(event: CurrentStateEvent) {
        isPrinting = PrinterUtils.isPrinting(event: event)
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
    
    func openChangeSelection(cell: SpoolSelectionViewCell) {
        performSegue(withIdentifier: "change_selection", sender: cell)
    }
    
    // MARK: - OctoPrintPluginsDelegate
    
    func pluginMessage(plugin: String, data: NSDictionary) {
        if plugin == Plugins.SPOOL_MANAGER {
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
        octoprintClient.loadSpools { (result: NSObject?, error: Error?, reponse: HTTPURLResponse) in
            var newSelections: Array<SpoolSelection> = []
            var newSpools: Array<Spool> = []
            if let error = error {
                self.showAlert(NSLocalizedString("Warning", comment: ""), message: error.localizedDescription, done: nil)
            } else if let json = result as? NSDictionary {
                if let selectionsArray = json["selectedSpools"] as? NSArray {
                    let spoolSelection = SpoolSelection(toolNumber: 0)
                    if selectionsArray.count > 0, let selection = selectionsArray[0] as? NSDictionary {
                        spoolSelection.parse(json: selection)
                    }
                    newSelections.append(spoolSelection)
                }
                if let spoolsArray = json["allSpools"] as? NSArray {
                    for case let spoolRaw as NSDictionary in spoolsArray {
                        let spool = Spool()
                        spool.parse(json: spoolRaw)
                        // Safety check that selections have specified a tool (no idea how plugin works - just in case)
                        if let _ = spool.spoolId, let _ = spool.profileVendor, let _ = spool.profileMaterial {
                            newSpools.append(spool)
                        }
                    }
                }
            }
            // Refresh table with new selections
            DispatchQueue.main.async {
                self.selections = newSelections
                self.spools = newSpools

                // Sort spools by vendor and material
                self.spools.sort { (left: Spool, right: Spool) -> Bool in
                    return left.profileVendor! + left.profileMaterial! < right.profileVendor! + right.profileMaterial!
                }

                self.tableView.reloadData()
            }
            // Execute done block when done
            done?()
        }
    }
    
    fileprivate func showAlert(_ title: String, message: String, done: (() -> Void)?) {
        UIUtils.showAlert(presenter: self, title: title, message: message, done: done)
    }
}
