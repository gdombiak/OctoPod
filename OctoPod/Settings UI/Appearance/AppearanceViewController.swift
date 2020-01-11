import UIKit

class AppearanceViewController: ThemedStaticUITableViewController, UIPopoverPresentationControllerDelegate {
    
    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()

    @IBOutlet weak var lightCell: UITableViewCell!
    @IBOutlet weak var darkCell: UITableViewCell!
    @IBOutlet weak var orangeCell: UITableViewCell!
    @IBOutlet weak var octoPrintCell: UITableViewCell!
    @IBOutlet weak var systemCell: UITableViewCell!
    
    @IBOutlet weak var lightLabel: UILabel!
    @IBOutlet weak var darkLabel: UILabel!
    @IBOutlet weak var orangeLabel: UILabel!
    @IBOutlet weak var octoPrintLabel: UILabel!
    @IBOutlet weak var systemLabel: UILabel!
    
    @IBOutlet weak var changeLanguageButton: UIButton!
    
    @IBOutlet weak var turnoffIdleLabel: UILabel!
    @IBOutlet weak var turnoffIdleSwitch: UISwitch!
    
    @IBOutlet weak var zoomInEnabledLabel: UILabel!
    @IBOutlet weak var zoomInEnabledSwitch: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let theme = Theme.currentTheme()
        lightLabel.textColor = theme.textColor()
        darkLabel.textColor = theme.textColor()
        orangeLabel.textColor = theme.textColor()
        octoPrintLabel.textColor = theme.textColor()
        systemLabel.textColor = theme.textColor()
        turnoffIdleLabel.textColor = theme.textColor()
        zoomInEnabledLabel.textColor = theme.textColor()
        changeLanguageButton.tintColor = theme.tintColor()
        
        turnoffIdleSwitch.isOn = !appConfiguration.turnOffIdleDisabled()
        zoomInEnabledSwitch.isOn = !appConfiguration.tempChartZoomDisabled()
        
        checkAppLockStatus()
        refreshSelectedTheme(theme: theme)
        
        // Do not let user select iOS Dark mode if older than iOS 13
        if #available(iOS 13.0, *) {
            systemLabel.isEnabled = true
            systemCell.isUserInteractionEnabled = true
        } else {
            systemLabel.isEnabled = false
            systemCell.isUserInteractionEnabled = false
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section != 0 {
            // Ignore if not selecting Theme
            return
        }
        if indexPath.row == 0 {
            Theme.switchTheme(choice: Theme.ThemeChoice.Light)
        } else if indexPath.row == 1 {
            Theme.switchTheme(choice: Theme.ThemeChoice.Dark)
        } else if indexPath.row == 2 {
            Theme.switchTheme(choice: Theme.ThemeChoice.Orange)
        } else if indexPath.row == 3 {
            Theme.switchTheme(choice: Theme.ThemeChoice.OctoPrint)
        } else {
            Theme.switchTheme(choice: Theme.ThemeChoice.System)
        }
        // Update navigation bar
        let theme = Theme.currentTheme()
        let printer = printerManager.getDefaultPrinter()
        navigationController?.navigationBar.barTintColor = theme.navigationTopColor(octoPrintColor: printer?.color)
        navigationController?.navigationBar.tintColor = theme.navigationTintColor(octoPrintColor: printer?.color)
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: theme.navigationTitleColor(octoPrintColor: printer?.color)]
        tabBarController?.tabBar.barTintColor = theme.tabBarColor()
        tabBarController?.tabBar.tintColor = theme.tintColor()
        // Refresh table
        viewWillAppear(true)
    }

    @IBAction func turnoffIdleChanged(_ sender: Any) {
        appConfiguration.turnOffIdleDisabled(disable: !turnoffIdleSwitch.isOn)
    }
    
    @IBAction func tempZoomChanged(_ sender: Any) {
        appConfiguration.tempChartZoomDisabled(disable: !zoomInEnabledSwitch.isOn)
    }
    
    fileprivate func refreshSelectedTheme(theme: Theme.ThemeChoice) {
        switch theme {
        case .Light:
            lightCell.accessoryType = .checkmark
            darkCell.accessoryType = .none
            orangeCell.accessoryType = .none
            octoPrintCell.accessoryType = .none
            systemCell.accessoryType = .none
        case .Dark:
            lightCell.accessoryType = .none
            darkCell.accessoryType = .checkmark
            orangeCell.accessoryType = .none
            octoPrintCell.accessoryType = .none
            systemCell.accessoryType = .none
        case .Orange:
            lightCell.accessoryType = .none
            darkCell.accessoryType = .none
            orangeCell.accessoryType = .checkmark
            octoPrintCell.accessoryType = .none
            systemCell.accessoryType = .none
        case .OctoPrint:
            lightCell.accessoryType = .none
            darkCell.accessoryType = .none
            orangeCell.accessoryType = .none
            octoPrintCell.accessoryType = .checkmark
            systemCell.accessoryType = .none
        case .System:
            lightCell.accessoryType = .none
            darkCell.accessoryType = .none
            orangeCell.accessoryType = .none
            octoPrintCell.accessoryType = .none
            systemCell.accessoryType = .checkmark
        }
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "goto_change_language" {
            segue.destination.popoverPresentationController!.delegate = self
            // Make the popover appear at the middle of the button
            segue.destination.popoverPresentationController!.sourceRect = CGRect(x: changeLanguageButton.frame.size.width/2, y: 0 , width: 0, height: 0)
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

    // MARK: - Private functions
    
    fileprivate func checkAppLockStatus() {
        // Do not let user change these settings when app is in locked mode
        changeLanguageButton.isEnabled = !appConfiguration.appLocked()
        turnoffIdleSwitch.isEnabled = !appConfiguration.appLocked()
        zoomInEnabledSwitch.isEnabled = !appConfiguration.appLocked()
    }
}
