import UIKit

class AppearanceViewController: ThemedStaticUITableViewController {

    @IBOutlet weak var lightCell: UITableViewCell!
    @IBOutlet weak var darkCell: UITableViewCell!
    
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
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
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
}
