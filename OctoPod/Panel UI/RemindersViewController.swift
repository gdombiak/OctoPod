import UIKit

class RemindersViewController: ThemedStaticUITableViewController {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()

    @IBOutlet weak var octopodPluginLabel: UILabel!
    @IBOutlet weak var updatedOctopodPluginLabel: UILabel!
    @IBOutlet weak var newAppleTVLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Theme labels
        themeLabels()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }

    // MARK: - Table view operations
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 36
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row == 0 {
            if let printer = printerManager.getDefaultPrinter() {
                return printer.octopodPluginInstalled ? 0 : super.tableView(tableView, heightForRowAt: indexPath)
            }
        } else if indexPath.row == 1 {
            if let printer = printerManager.getDefaultPrinter() {
                return printer.octopodPluginInstalled ? super.tableView(tableView, heightForRowAt: indexPath) : 0
            }
        }
        return super.tableView(tableView, heightForRowAt: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 || indexPath.row == 1 {
            if let url = URL(string: "https://plugins.octoprint.org/plugins/octopod/") {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }

    // MARK: - Private functions
    fileprivate func themeLabels() {
        let theme = Theme.currentTheme()
        let textLabelColor = theme.labelColor()
        
        octopodPluginLabel.textColor = textLabelColor
        updatedOctopodPluginLabel.textColor = textLabelColor
        newAppleTVLabel.textColor = textLabelColor
    }
}
