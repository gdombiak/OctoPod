import UIKit

class SecurityViewController: ThemedStaticUITableViewController {

    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()

    @IBOutlet weak var appLockLabel: UILabel!
    @IBOutlet weak var appLockSwitch: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let theme = Theme.currentTheme()
        appLockLabel.textColor = theme.textColor()

        appLockSwitch.isOn = appConfiguration.appLocked()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    @IBAction func appLockChanged(_ sender: Any) {
        appConfiguration.appLocked(locked: appLockSwitch.isOn)
    }
}
