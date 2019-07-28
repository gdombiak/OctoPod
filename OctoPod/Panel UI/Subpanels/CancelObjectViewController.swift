import UIKit

class CancelObjectViewController: ThemedDynamicUITableViewController, SubpanelViewController {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()

    @IBOutlet weak var footerView: UIView!
    @IBOutlet weak var footerLabel: UILabel!
    
    var cancelObjects: [CancelObject] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        // Some bug in XCode Storyboards is not translating text of refresh control so let's do it manually
        self.refreshControl?.attributedTitle = NSAttributedString(string: NSLocalizedString("Pull down to refresh", comment: ""))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Theme footer
        let theme = Theme.currentTheme()
        footerView.backgroundColor = theme.cellBackgroundColor()
        footerLabel.textColor = theme.labelColor()
        
        // Hide footer. Will appear only if old plugin version is detected
        footerView.isHidden = true

        // Fetch and render custom controls
        refreshCancelObjects(done: nil)
    }

    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cancelObjects.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return NSLocalizedString("Cancel Objects", comment: "https://github.com/paukstelis/Octoprint-Cancelobject")
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cancel_object_cell", for: indexPath) as! CancelObjectViewCell
        
        // Configure the cell
        cell.row = indexPath.row
        cell.cancelObjectViewController = self
        
        cell.objectLabel?.text = cancelObjects[indexPath.row].object
        cell.objectLabel?.textColor = Theme.currentTheme().textColor()

        cell.cancelButton.isEnabled = !cancelObjects[indexPath.row].cancelled && !appConfiguration.appLocked()
        
        return cell
    }

    // MARK: - SubpanelViewController
    
    func printerSelectedChanged() {
        // Only refresh UI if view controller is being shown
        if let _ = parent {
            // Fetch and render list of objects that can be cancelled
            refreshCancelObjects(done: nil)
        }
    }
    
    func currentStateUpdated(event: CurrentStateEvent) {
        // Do nothing
    }
    
    func position() -> Int {
        return 20
    }

    // MARK: - Button operations

    func cancelObject(objectId: Int) {
        let objectId = cancelObjects[objectId].id
        showConfirm(message: NSLocalizedString("Confirm cancel object", comment: ""), yes: { (UIAlertAction) -> Void in
            self.octoprintClient.cancelObject(id: objectId) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                if requested {
                    // Fetch and refresh UI
                    self.refreshCancelObjects(done: nil)
                } else if let _ = error {
                    self.showAlert(NSLocalizedString("Warning", comment: ""), message: error!.localizedDescription)
                } else if response.statusCode != 204 {
                    self.showAlert(NSLocalizedString("Warning", comment: ""), message: String(format: NSLocalizedString("Failed to request to cancel object", comment: ""), response.statusCode))
                }
            }
        }, no: { (UIAlertAction) -> Void in
            // Do nothing
        })
    }
    
    // MARK: - Refresh
    
    @IBAction func refreshControls(_ sender: UIRefreshControl) {
        // Fetch and render custom controls
        refreshCancelObjects(done: {
            DispatchQueue.main.async {
                sender.endRefreshing()
            }
        })
    }
    
    // MARK: - Private functions
    
    fileprivate func refreshCancelObjects(done: (() -> Void)?) {
        octoprintClient.getCancelObjects { (cancelObjects: Array<CancelObject>?, error: Error?, response: HTTPURLResponse) in
            if let objects = cancelObjects {
                self.cancelObjects = objects
            } else {
                self.cancelObjects = []
            }
            DispatchQueue.main.async {
                if self.footerView != nil {
                    // We might not be initialized yet so need to protect from this
                    self.footerView.isHidden = true
                }
                self.tableView.reloadData()
            }
            if let _ = error {
                self.showAlert(NSLocalizedString("Warning", comment: ""), message: error!.localizedDescription)
            } else if response.statusCode == 400 {
                // Old version of Cancel Object plugin do not have an API to get list of cancel objects
                DispatchQueue.main.async {
                    if self.footerView != nil {
                        // We might not be initialized yet so need to protect from this
                        self.footerView.isHidden = false
                    }
                }
            } else if response.statusCode != 200 {
                self.showAlert(NSLocalizedString("Warning", comment: ""), message: String(format: NSLocalizedString("Failed to get list of cancel objects", comment: ""), response.statusCode))
            }
            // Execute done block when done
            done?()
        }
    }
    
    fileprivate func showAlert(_ title: String, message: String) {
        UIUtils.showAlert(presenter: self, title: title, message: message, done: nil)
    }

    fileprivate func showConfirm(message: String, yes: @escaping (UIAlertAction) -> Void, no: @escaping (UIAlertAction) -> Void) {
        UIUtils.showConfirm(presenter: self, message: message, yes: yes, no: no)
    }
}
