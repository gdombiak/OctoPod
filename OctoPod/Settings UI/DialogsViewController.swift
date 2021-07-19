import UIKit

class DialogsViewController: ThemedStaticUITableViewController {
    
    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()

    @IBOutlet weak var onConnectLabel: UILabel!
    @IBOutlet weak var onDisconnectLabel: UILabel!
    @IBOutlet weak var promptExtrudeSpeedLabel: UILabel!
    @IBOutlet weak var startPrintLabel: UILabel!
    @IBOutlet weak var pausePrintLabel: UILabel!
    @IBOutlet weak var resumePrintLabel: UILabel!

    @IBOutlet weak var onConnectSwitch: UISwitch!
    @IBOutlet weak var onDisconnectSwitch: UISwitch!
    @IBOutlet weak var promptExtrudeSpeedSwitch: UISwitch!
    @IBOutlet weak var startPrintSwitch: UISwitch!
    @IBOutlet weak var pausePrintSwitch: UISwitch!
    @IBOutlet weak var resumePrintSwitch: UISwitch!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Theme labels
        let theme = Theme.currentTheme()
        onConnectLabel.textColor = theme.textColor()
        onDisconnectLabel.textColor = theme.textColor()
        promptExtrudeSpeedLabel.textColor = theme.textColor()
        startPrintLabel.textColor = theme.textColor()
        pausePrintLabel.textColor = theme.textColor()
        resumePrintLabel.textColor = theme.textColor()
        
        // Configure state of switches
        onConnectSwitch.isOn = appConfiguration.confirmationOnConnect()
        onDisconnectSwitch.isOn = appConfiguration.confirmationOnDisconnect()
        promptExtrudeSpeedSwitch.isOn = appConfiguration.promptSpeedExtrudeRetract()
        startPrintSwitch.isOn = appConfiguration.confirmationStartPrint()
        pausePrintSwitch.isOn = appConfiguration.confirmationPausePrint()
        resumePrintSwitch.isOn = appConfiguration.confirmationResumePrint()

        // Only allow to change settings if app is not in read-only mode
        onConnectSwitch.isEnabled = !appConfiguration.appLocked()
        onDisconnectSwitch.isEnabled = !appConfiguration.appLocked()
        promptExtrudeSpeedSwitch.isEnabled = !appConfiguration.appLocked()
        startPrintSwitch.isEnabled = !appConfiguration.appLocked()
        pausePrintSwitch.isEnabled = !appConfiguration.appLocked()
        resumePrintSwitch.isEnabled = !appConfiguration.appLocked()
    }

    @IBAction func onConnectChanged(_ sender: Any) {
        appConfiguration.confirmationOnConnect(enable: onConnectSwitch.isOn)
    }
    
    @IBAction func onDisconnectChanged(_ sender: Any) {
        appConfiguration.confirmationOnDisconnect(enable: onDisconnectSwitch.isOn)
    }

    @IBAction func onPromptExtrudeSpeedChanged(_ sender: Any) {
        appConfiguration.promptSpeedExtrudeRetract(enable: promptExtrudeSpeedSwitch.isOn)
    }

    @IBAction func startPrintChanged(_ sender: Any) {
        appConfiguration.confirmationStartPrint(enable: startPrintSwitch.isOn)
    }

    @IBAction func pausePrintChanged(_ sender: Any) {
        appConfiguration.confirmationPausePrint(enable: pausePrintSwitch.isOn)
    }

    @IBAction func resumePrintChanged(_ sender: Any) {
        appConfiguration.confirmationResumePrint(enable: resumePrintSwitch.isOn)
    }
}
