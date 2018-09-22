import UIKit

class SettingsViewController: ThemedStaticUITableViewController {

    @IBOutlet weak var printersLabel: UILabel!
    @IBOutlet weak var appearanceLabel: UILabel!
    @IBOutlet weak var securityLabel: UILabel!
    @IBOutlet weak var dialogsLabel: UILabel!
    @IBOutlet weak var devicesLabel: UILabel!
    @IBOutlet weak var supportLabel: UILabel!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let theme = Theme.currentTheme()
        printersLabel.textColor = theme.textColor()
        appearanceLabel.textColor = theme.textColor()
        securityLabel.textColor = theme.textColor()
        dialogsLabel.textColor = theme.textColor()
        devicesLabel.textColor = theme.textColor()
        supportLabel.textColor = theme.textColor()
    }
}
