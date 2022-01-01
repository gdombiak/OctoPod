import UIKit

class SettingsViewController: ThemedStaticUITableViewController {

    @IBOutlet weak var printersLabel: UILabel!
    @IBOutlet weak var appearanceLabel: UILabel!
    @IBOutlet weak var securityLabel: UILabel!
    @IBOutlet weak var dialogsLabel: UILabel!
    @IBOutlet weak var appleWatchLabel: UILabel!
    @IBOutlet weak var devicesLabel: UILabel!
    @IBOutlet weak var siriLabel: UILabel!
    @IBOutlet weak var supportLabel: UILabel!
    @IBOutlet weak var sponsorLabel: UILabel!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let theme = Theme.currentTheme()
        printersLabel.textColor = theme.textColor()
        appearanceLabel.textColor = theme.textColor()
        securityLabel.textColor = theme.textColor()
        dialogsLabel.textColor = theme.textColor()
        appleWatchLabel.textColor = theme.textColor()
        devicesLabel.textColor = theme.textColor()
        siriLabel.textColor = theme.textColor()
        supportLabel.textColor = theme.textColor()
        sponsorLabel.textColor = theme.textColor()
    }
    
    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        super.tableView(tableView, willDisplayFooterView: view, forSection: section)
        let footer: UITableViewHeaderFooterView = view as! UITableViewHeaderFooterView
        footer.textLabel?.textAlignment = .center
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let dictionary = Bundle.main.infoDictionary!
        let version = dictionary["CFBundleShortVersionString"] as! String
        let build = dictionary["CFBundleVersion"] as! String
        return "OctoPod v\(version) build \(build)"
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row == 4 && UIDevice.current.userInterfaceIdiom == .pad {
            // Hide Apple Watch settings when on the iPad
            return 0
        }
        return 44
    }
}
