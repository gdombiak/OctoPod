import UIKit

class DialogsViewController: ThemedStaticUITableViewController {
    
    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()

    @IBOutlet weak var onConnectLabel: UILabel!
    @IBOutlet weak var onDisconnectLabel: UILabel!
    
    @IBOutlet weak var onConnectSwitch: UISwitch!
    @IBOutlet weak var onDisconnectSwitch: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Theme labels
        let theme = Theme.currentTheme()
        onConnectLabel.textColor = theme.textColor()
        onDisconnectLabel.textColor = theme.textColor()
        
        // Configure state of switches
        onConnectSwitch.isOn = appConfiguration.confirmationOnConnect()
        onDisconnectSwitch.isOn = appConfiguration.confirmationOnDisconnect()
        
        // Only allow to change settings if app is not in read-only mode
        onConnectSwitch.isEnabled = !appConfiguration.appLocked()
        onDisconnectSwitch.isEnabled = !appConfiguration.appLocked()
    }

    @IBAction func onConnectChanged(_ sender: Any) {
        appConfiguration.confirmationOnConnect(enable: onConnectSwitch.isOn)
    }
    
    @IBAction func onDisconnectChanged(_ sender: Any) {
        appConfiguration.confirmationOnDisconnect(enable: onDisconnectSwitch.isOn)
    }
}
