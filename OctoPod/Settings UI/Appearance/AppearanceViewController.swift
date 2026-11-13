import UIKit

class AppearanceViewController: ThemedStaticUITableViewController, UIPopoverPresentationControllerDelegate {

    override func usesDynamicTypeRows() -> Bool {
        return true
    }
    
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
    @IBOutlet weak var languageRestartLabel: UILabel!
    
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
        languageRestartLabel.textColor = theme.tintColor()
        
        turnoffIdleSwitch.isOn = !appConfiguration.turnOffIdleDisabled()
        zoomInEnabledSwitch.isOn = !appConfiguration.tempChartZoomDisabled()
        
        checkAppLockStatus()
        refreshSelectedTheme(theme: theme)
        
        systemLabel.isEnabled = true
        systemCell.isUserInteractionEnabled = true
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
        let printer = printerManager.getDefaultPrinter()
        (tabBarController as? TabBarController)?.refreshAppearance()
        if let navigationController = navigationController as? NavigationController {
            navigationController.refreshForPrinterColors(color: printer?.color)
        } else if let navigationController = navigationController {
            ThemeUIUtils.applyTheme(navigationController: navigationController, octoPrintColor: printer?.color)
        }
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
            guard let popover = segue.destination.popoverPresentationController else { return }
            popover.delegate = self
            let button = changeLanguageButton!
            popover.sourceRect = button.bounds
            // A tall accessibility row does not fit in the sliver above a button that
            // sits near the navigation bar. Open toward whichever side has more room,
            // and keep the popover inside that side. iPadOS 27 will not present a
            // popover that is taller than the space around the button.
            let frame = button.convert(button.bounds, to: view)
            let above = frame.minY - view.safeAreaInsets.top
            let below = view.bounds.height - view.safeAreaInsets.bottom - frame.maxY
            popover.permittedArrowDirections = below >= above ? .up : .down
            segue.destination.preferredContentSize = ChangeLanguageViewController.popoverSize(fitting: view.bounds, sourceFrame: frame, safeArea: view.safeAreaInsets)
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
