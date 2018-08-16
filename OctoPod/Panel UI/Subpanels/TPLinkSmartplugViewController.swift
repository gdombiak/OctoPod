import UIKit

class TPLinkSmartplugViewController: ThemedDynamicUITableViewController, SubpanelViewController, OctoPrintSettingsDelegate {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()

    var plugs: [Printer.TPLinkSmartplug] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        renderPrinter()
        // Listen to changes to OctoPrint Settings
        octoprintClient.octoPrintSettingsDelegates.append(self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Stop listening to changes to OctoPrint Settings
        octoprintClient.remove(octoPrintSettingsDelegate: self)
    }

    // MARK: - SubpanelViewController
    
    func printerSelectedChanged() {
        renderPrinter()
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    // Notification that OctoPrint state has changed. This may include printer status information
    func currentStateUpdated(event: CurrentStateEvent) {
        // TODO Implement THIS
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return plugs.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "tplink_plug_cell", for: indexPath)
        
        let label = cell.viewWithTag(100) as? UILabel
        label?.text = plugs[indexPath.row].label
        label?.textColor = Theme.currentTheme().labelColor()
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "TPLink Smartplugs"
    }
    
    // MARK: - OctoPrintSettingsDelegate
    
    func tplinkSmartpluglChanged(plugs: Array<Printer.TPLinkSmartplug>) {
        self.plugs = plugs
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    // MARK: - Private functions
    
    fileprivate func renderPrinter() {
        if let printer = printerManager.getDefaultPrinter() {
            if let existingPlugs = printer.getTPLinkSmartplugs() {
                plugs = existingPlugs
            } else {
                plugs = []
            }
        } else {
            plugs = []
        }
    }
}
