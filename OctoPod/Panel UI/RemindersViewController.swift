import UIKit

class RemindersViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private static let REMINDER_2_3 = "PANEL_REMINDERS_SHOWN_2_3"
    private static let REMINDER_3_0 = "PANEL_REMINDERS_SHOWN_3_0"
    private static let REMINDER_3_2 = "PANEL_REMINDERS_SHOWN_3_2"
    private static let REMINDER_3_12 = "PANEL_REMINDERS_SHOWN_3_12"

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    var currentTheme: Theme.ThemeChoice!

    @IBOutlet weak var tableView: UITableView!

    @IBOutlet weak var dismissButton: UIButton!
    
    var messages: Array<ReminderMessage> = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Remember current theme so we know when to repaint
        currentTheme = Theme.currentTheme()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Add reminders we want to display
        if let printer = printerManager.getDefaultPrinter() {
            let test = false
            // Always remind user to install OctoPod plugin if not already installed
            if test || !printer.octopodPluginInstalled {
                messages.append(ReminderMessage(message: NSLocalizedString("Install OctoPod plugin for OctoPrint to receive immediate push notifications with camera snapshots", comment: ""), url: "https://plugins.octoprint.org/plugins/octopod/"))
            }
            // Only tell user to update OctoPod plugin if plugin is installed and user is updating to v3.2
            let upgradeTo3_2 = (UserDefaults.standard.bool(forKey: RemindersViewController.REMINDER_2_3) || UserDefaults.standard.bool(forKey: RemindersViewController.REMINDER_3_0)) && !UserDefaults.standard.bool(forKey: RemindersViewController.REMINDER_3_2)
            if test || printer.octopodPluginInstalled && upgradeTo3_2 {
                messages.append(ReminderMessage(message: NSLocalizedString("Update OctoPod plugin for OctoPrint to receive notifications at specified layers", comment: ""), url: "https://plugins.octoprint.org/plugins/octopod/"))
            }
            // Only tell user about new apple tv app if user never saw it (starting on v3.2) - needs to be updated for new reminders!!!
            let showAppleTV = !UserDefaults.standard.bool(forKey: RemindersViewController.REMINDER_3_2) && !UserDefaults.standard.bool(forKey: RemindersViewController.REMINDER_3_12)
            if test || showAppleTV {
                messages.append(ReminderMessage(message: NSLocalizedString("New Apple TV app is now available", comment: ""), url: nil))
            }
            // Only tell user to uninstall old copy of Apple Watch app when updating to 3.12
            let upgradeTo3_12 = (UserDefaults.standard.bool(forKey: RemindersViewController.REMINDER_2_3) || UserDefaults.standard.bool(forKey: RemindersViewController.REMINDER_3_0) || UserDefaults.standard.bool(forKey: RemindersViewController.REMINDER_3_2)) && !UserDefaults.standard.bool(forKey: RemindersViewController.REMINDER_3_12)
            if test || upgradeTo3_12 {
                messages.append(ReminderMessage(message: NSLocalizedString("Remove old OctoPod app from Apple Watch", comment: ""), url: nil))
            }
        }

        ThemeUIUtils.applyTheme(table: tableView, staticCells: false)

        if currentTheme != Theme.currentTheme() {
            tableView.reloadData()
            currentTheme = Theme.currentTheme()
        }

        // Set background color of popover and its arrow based on current theme
        self.popoverPresentationController?.backgroundColor = currentTheme.backgroundColor()
        self.dismissButton.tintColor = currentTheme.tintColor()
    }

    // MARK: - Table view data source

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "reminder_cell", for: indexPath)

        // Configure the cell...
        if let label = cell.viewWithTag(100) as? UILabel {
            label.text = messages[indexPath.row].message
        }
        cell.isUserInteractionEnabled = messages[indexPath.row].url != nil

        return cell
    }
    
    // MARK: - Table view operations
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return NSLocalizedString("Reminders", comment: "")
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 36
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 1
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let urlString = messages[indexPath.row].url {
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }

    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        ThemeUIUtils.themeCell(cell: cell)
        if let label = cell.viewWithTag(100) as? UILabel {
            // Use "button" color if user can select on cell
            label.textColor = messages[indexPath.row].url != nil ? currentTheme.tintColor() : currentTheme.labelColor()
        }
    }
}

struct ReminderMessage {
    var message: String
    var url: String?
}
