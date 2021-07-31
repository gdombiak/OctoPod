import UIKit

class LayerNotificationsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()

    var currentTheme: Theme.ThemeChoice!
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var addLayerTextField: UITextField!
    @IBOutlet weak var addLayerButton: UIButton!

    var layers: Array<String> = []

    override func viewDidLoad() {
        super.viewDidLoad()

        // Remember current theme so we know when to repaint
        currentTheme = Theme.currentTheme()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ThemeUIUtils.applyTheme(table: tableView, staticCells: false)

        if currentTheme != Theme.currentTheme() {
            tableView.reloadData()
            currentTheme = Theme.currentTheme()
        }

        // Set background color of popover and its arrow based on current theme
        self.popoverPresentationController?.backgroundColor = currentTheme.backgroundColor()
        self.addLayerButton.tintColor = currentTheme.tintColor()

        // Enable/Disable add button depending on entered text in addLayerTextField
        enableOrDisableAddButton()

        // Fetch and render existing layer notifications
        refreshLayerNotifications(done: nil)
    }

    // MARK: - Table view data source

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return layers.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "layer", for: indexPath)

        // Configure the cell...
        cell.textLabel?.text = layers[indexPath.row]

        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        ThemeUIUtils.themeCell(cell: cell)
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let layerToDelete = layers[indexPath.row]
            // Assume operation was successful
            layers.remove(at: indexPath.row)
            // Refresh UI table
            tableView.reloadData()

            // Delete layer notification by letting OctoPod plugin for OctoPrint know
            self.octoprintClient.layerNotification(layer: layerToDelete, add: false) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                if !requested {
                    // Show alert in case of error and refetch layers from plugin
                    self.showAlert(NSLocalizedString("Warning", comment: ""), message: String(format: NSLocalizedString("Failed to delete layer notification", comment: ""), response.statusCode))
                    // Refresh list of layer notifications with existing ones on the server
                    self.refreshLayerNotifications(done: nil)
                }
            }
        }
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return tableView.isEditing ? .none : .delete
    }
    
    // MARK: Button actions

    @IBAction func addLayerClicked(_ sender: Any) {
        if let newLayer = addLayerTextField.text {
            // Assume operation was successful
            layers.append(newLayer)
            layers = sortedLayers(input: layers)
            // Refresh UI table
            tableView.reloadData()

            // Add layer notification by letting OctoPod plugin for OctoPrint know
            self.octoprintClient.layerNotification(layer: newLayer, add: true) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                if !requested {
                    // Show alert in case of error and refetch layers from plugin
                    self.showAlert(NSLocalizedString("Warning", comment: ""), message: String(format: NSLocalizedString("Failed to add new layer notification", comment: ""), response.statusCode))
                    // Refresh list of layer notifications with existing ones on the server
                    self.refreshLayerNotifications(done: nil)
                }
            }

            // Reset layer number and disable add button
            addLayerTextField.text = nil
            addLayerButton.isEnabled = false
        }
    }
    
    @IBAction func newLayerChanged(_ sender: Any) {
        enableOrDisableAddButton()
    }
    
    // MARK: Private functions
    
    fileprivate func refreshLayerNotifications(done: (() -> Void)?) {
        octoprintClient.getLayerNotifications(callback: { (existingLayers: Array<String>?, error: Error?, response: HTTPURLResponse) in
            if let existingLayers = existingLayers {
                self.layers = self.sortedLayers(input: existingLayers)
            } else {
                self.layers = []
            }
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
            if let _ = error {
                self.showAlert(NSLocalizedString("Warning", comment: ""), message: error!.localizedDescription)
            } else if response.statusCode != 200 {
                self.showAlert(NSLocalizedString("Warning", comment: ""), message: String(format: NSLocalizedString("Failed to get list of layer notifications", comment: ""), response.statusCode))
            }
            // Execute done block when done
            done?()
        })
    }
    
    fileprivate func sortedLayers(input: [String]) -> [String] {
        return input.sorted(by: { (left, right) -> Bool in
            return Int(left)! < Int(right)!
        })
    }
    
    fileprivate func showAlert(_ title: String, message: String) {
        UIUtils.showAlert(presenter: self, title: title, message: message, done: nil)
    }

    fileprivate func enableOrDisableAddButton() {
        self.addLayerButton.isEnabled = self.addLayerTextField.text != nil && !self.addLayerTextField.text!.isEmpty
    }
}
