import UIKit
import LocalAuthentication

class SecurityViewController: ThemedStaticUITableViewController, AppConfigurationDelegate {

    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()

    @IBOutlet weak var appLockBiometricsLabel: UILabel!
    @IBOutlet weak var appLockLabel: UILabel!
    @IBOutlet weak var appLockBiometricsSwitch: UISwitch!
    @IBOutlet weak var appLockSwitch: UISwitch!
    @IBOutlet weak var appAutoLockLabel: UILabel!
    @IBOutlet weak var appAutoLockSwitch: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Listen to changes when app is automatically locked or unlocked
        appConfiguration.delegates.append(self)

        // Theme labels
        let theme = Theme.currentTheme()
        appLockBiometricsLabel.textColor = theme.textColor()
        appLockLabel.textColor = theme.textColor()
        appAutoLockLabel.textColor = theme.textColor()

        // Configure state of switches
        appLockBiometricsSwitch.isOn = appConfiguration.appLockedRequiresAuthentication()
        appLockSwitch.isOn = appConfiguration.appLocked()
        appAutoLockSwitch.isOn = appConfiguration.appAutoLock()
        reviewBiometricsSwitch()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Stop listening to changes when app is automatically locked or unlocked
        appConfiguration.remove(appConfigurationDelegate: self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    // MARK: - App Lock switches
    
    @IBAction func appLockBiometricsChanged(_ sender: Any) {
        appConfiguration.appLockedRequiresAuthentication(requires: appLockBiometricsSwitch.isOn)
    }
    
    @IBAction func appLockChanged(_ sender: Any) {
        if !appLockSwitch.isOn && appLockBiometricsSwitch.isOn {
            // User needs to authenticate to be able to disable read-only mode
            authenticateToUnlock()
        } else {
            // User is manually controlling lock setting so disable auto-lock
            appConfiguration.appAutoLock(autoLock: false)
            appAutoLockSwitch.isOn = false
            // Update app lock setting based on user requests
            appConfiguration.appLocked(locked: appLockSwitch.isOn)
            reviewBiometricsSwitch()
        }
    }
    
    @IBAction func appAutoLockChanged(_ sender: Any) {
        appConfiguration.appAutoLock(autoLock: appAutoLockSwitch.isOn)
    }
    
    // MARK: - AppConfigurationDelegate
    
    func appLockChanged(locked: Bool) {
        DispatchQueue.main.async {
            self.appLockSwitch.isOn = locked
        }
    }
    
    // MARK: - Private functions
    
    fileprivate func authenticateToUnlock() {
        let localAuthenticationContext = LAContext()
        localAuthenticationContext.localizedFallbackTitle = "Use Passcode"
        
        var authError: NSError?
        let reasonString = "To disable read-only mode"
        
        if localAuthenticationContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) {
            
            localAuthenticationContext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reasonString) { success, evaluateError in
                
                if success {
                    // User authenticated successfully, take appropriate action
                    DispatchQueue.main.async {
                        // User is manually controlling lock setting so disable auto-lock
                        self.appConfiguration.appAutoLock(autoLock: false)
                        self.appAutoLockSwitch.isOn = false

                        self.appConfiguration.appLocked(locked: false)
                        self.reviewBiometricsSwitch()
                    }
                } else {
                    // User failed to authenticate so revert change
                    DispatchQueue.main.async {
                        self.appLockSwitch.isOn = true
                    }
                }
            }
        }
    }

    fileprivate func reviewBiometricsSwitch() {
        // Do not let user change these settings when app is in locked mode
        appLockBiometricsSwitch.isEnabled = !appLockSwitch.isOn
        appAutoLockSwitch.isEnabled = !appLockSwitch.isOn
    }
}
