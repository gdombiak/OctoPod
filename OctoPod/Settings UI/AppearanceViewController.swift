import UIKit

class AppearanceViewController: ThemedStaticUITableViewController {
    
    private static let APP_SYSTEM_LANGUAGE_OVERRIDE = "APP_SYSTEM_LANGUAGE_OVERRIDE"

    @IBOutlet weak var lightCell: UITableViewCell!
    @IBOutlet weak var darkCell: UITableViewCell!
    @IBOutlet weak var languageControl: UISegmentedControl!
    
    @IBOutlet weak var lightLabel: UILabel!
    @IBOutlet weak var darkLabel: UILabel!
    
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
        refreshSelectedTheme(theme: theme)
        
        // Set language being used
        let languageOverride = UserDefaults.standard.object(forKey: AppearanceViewController.APP_SYSTEM_LANGUAGE_OVERRIDE) != nil
        languageControl.selectedSegmentIndex = languageOverride ? 1 : 0
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
//        applyTheme(table: tableView)
//        tableView.reloadData()
//        refreshSelectedTheme()
    }

    fileprivate func refreshSelectedTheme(theme: Theme.ThemeChoice) {
        let lightSelected = theme == Theme.ThemeChoice.Light
        
        lightCell.accessoryType = lightSelected ? .checkmark : .none
        darkCell.accessoryType = lightSelected ? .none : .checkmark
    }
    
    @IBAction func languageChanged(_ sender: Any) {
        let languageKey = "AppleLanguages"
        let defaults = UserDefaults.standard
        if languageControl.selectedSegmentIndex == 0 {
            defaults.removeObject(forKey: languageKey)
            defaults.removeObject(forKey: AppearanceViewController.APP_SYSTEM_LANGUAGE_OVERRIDE)
        } else {
            defaults.set(["en"], forKey: languageKey)
            defaults.set(true, forKey: AppearanceViewController.APP_SYSTEM_LANGUAGE_OVERRIDE)
        }
    }
}
