import UIKit

class AppearanceViewController: ThemedStaticUITableViewController, UIPopoverPresentationControllerDelegate {
    
    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()

    @IBOutlet weak var lightCell: UITableViewCell!
    @IBOutlet weak var darkCell: UITableViewCell!
    
    @IBOutlet weak var lightLabel: UILabel!
    @IBOutlet weak var darkLabel: UILabel!
    
    @IBOutlet weak var changeLanguageButton: UIButton!
    
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
        zoomInEnabledLabel.textColor = theme.textColor()
        
        zoomInEnabledSwitch.isOn = !appConfiguration.tempChartZoomDisabled()
        
        refreshSelectedTheme(theme: theme)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section != 0 {
            // Ignore if not selecting Theme
            return
        }
        if indexPath.row == 0 {
            Theme.switchTheme(choice: Theme.ThemeChoice.Light)
        } else {
            Theme.switchTheme(choice: Theme.ThemeChoice.Dark)
        }
        // Update navigation bar
        let theme = Theme.currentTheme()
        navigationController?.navigationBar.barTintColor = theme.navigationTopColor()
        tabBarController?.tabBar.barTintColor = theme.tabBarColor()
        // Refresh table
        viewWillAppear(true)
    }

    @IBAction func tempZoomChanged(_ sender: Any) {
        appConfiguration.tempChartZoomDisabled(disable: !zoomInEnabledSwitch.isOn)
    }
    
    fileprivate func refreshSelectedTheme(theme: Theme.ThemeChoice) {
        let lightSelected = theme == Theme.ThemeChoice.Light
        
        lightCell.accessoryType = lightSelected ? .checkmark : .none
        darkCell.accessoryType = lightSelected ? .none : .checkmark
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
}
