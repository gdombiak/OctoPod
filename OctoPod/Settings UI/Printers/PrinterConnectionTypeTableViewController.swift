import UIKit

class PrinterConnectionTypeTableViewController: ThemedStaticUITableViewController {

    @IBOutlet weak var appKeyLabel: UILabel!
    @IBOutlet weak var appKeyDetailsLabel: UILabel!
    @IBOutlet weak var globalKeyLabel: UILabel!
    @IBOutlet weak var globalKeyDetailsLabel: UILabel!
    @IBOutlet weak var octoeverywhereLabel: UILabel!
    @IBOutlet weak var octoeverywhereDetailsLabel: UILabel!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let theme = Theme.currentTheme()
        appKeyLabel.textColor = theme.textColor()
        appKeyDetailsLabel.textColor = theme.textColor()
        globalKeyLabel.textColor = theme.textColor()
        globalKeyDetailsLabel.textColor = theme.textColor()
        octoeverywhereLabel.textColor = theme.textColor()
        octoeverywhereDetailsLabel.textColor = theme.textColor()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            performSegue(withIdentifier: "selectedAppKey", sender: self)
        } else if indexPath.row == 1 {
            performSegue(withIdentifier: "selectedOctoEverywhere", sender: self)
        } else {
            performSegue(withIdentifier: "selectedGlobalAPI", sender: self)
        }
    }
}
