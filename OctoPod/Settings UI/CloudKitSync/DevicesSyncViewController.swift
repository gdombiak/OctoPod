import UIKit
import CloudKit

class DevicesSyncViewController: ThemedStaticUITableViewController {

    let cloudKitPrinterManager: CloudKitPrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).cloudKitPrinterManager }()
    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()

    @IBOutlet weak var syncEnabledLabel: UILabel!
    @IBOutlet weak var syncEnabledSwitch: UISwitch!

    @IBOutlet weak var resetFromiCloudButton: UIButton!
    @IBOutlet weak var resetFromLocalButton: UIButton!
    
    @IBOutlet weak var loginMessageCell: UITableViewCell!
    
    // Flag to know if we are running a process to reset things
    var resetting: Bool = false
    
    var accountStatus: CKAccountStatus?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Theme labels
        let theme = Theme.currentTheme()
        syncEnabledLabel.textColor = theme.textColor()
        
        // Enable/Disable controls depending on app locked status
        syncEnabledSwitch.isEnabled = !appConfiguration.appLocked()

        // Configure state of switch
        syncEnabledSwitch.isOn = !cloudKitPrinterManager.cloudKitSyncStopped()

        CKContainer.default().accountStatus { (status: CKAccountStatus, error: Error?) in
            if let error = error {
                NSLog("Error getting iCloud login status: \(error)")
            }
            self.accountStatus = status
            DispatchQueue.main.async {
                // Enable/disable reset buttons depending on switch status
                self.enableOrDisableButtons()
            }
        }
    }

    @IBAction func cloudSyncEnabledSwitch(_ sender: Any) {
        // Enable/Disable synchornizing devices by iCloud
        cloudKitPrinterManager.stopCloudKitSync(stop: !syncEnabledSwitch.isOn)
        
        // Enable/disable reset buttons depending on switch status
        enableOrDisableButtons()
    }
    
    // Remove locally stored printers and import again printers stored in iCloud
    @IBAction func resetLocalPrinters(_ sender: Any) {
        UIUtils.showConfirm(presenter: self, message: "Printers stored in app will be deleted and replaced with ones stored in iCloud. Proceed?", yes: { (action) in
            // Indicate that we are running a process to reset things
            self.resetting = true
            self.enableOrDisableButtons()
            self.cloudKitPrinterManager.resetLocalPrinters(completionHandler: {
                // Done with no errors
                UIUtils.showAlert(presenter: self, title: "Reset", message: "Operation finished", done: {
                    // Indicate that we are no longer running a process to reset things
                    self.resetting = false
                    self.enableOrDisableButtons()
                })
            }, errorHandler: {
                // Some error happened
                UIUtils.showAlert(presenter: self, title: "Reset", message: "Operation found errors. Go to activity log for more information", done: {
                    // Indicate that we are no longer running a process to reset things
                    self.resetting = false
                    self.enableOrDisableButtons()
                })
            })
        }) { (action) in
            // Do nothing since user changed his/her mind
        }
    }
    
    @IBAction func resetCloudKit(_ sender: Any) {
        UIUtils.showConfirm(presenter: self, message: "Printers stored in iCloud will be deleted and replaced with ones stored in the app. Proceed?", yes: { (action) in
            // Indicate that we are running a process to reset things
            self.resetting = true
            self.enableOrDisableButtons()
            self.cloudKitPrinterManager.resetCloutKit(completionHandler: {
                // Done with no errors
                UIUtils.showAlert(presenter: self, title: "Reset", message: "Operation finished", done: {
                    // Indicate that we are no longer running a process to reset things
                    self.resetting = false
                    self.enableOrDisableButtons()
                })
            }, errorHandler: {
                // Some error happened
                UIUtils.showAlert(presenter: self, title: "Reset", message: "Operation found errors. Go to activity log for more information", done: {
                    // Indicate that we are no longer running a process to reset things
                    self.resetting = false
                    self.enableOrDisableButtons()
                })
            })
        }) { (action) in
            // Do nothing since user changed his/her mind
        }
    }
    
    fileprivate func enableOrDisableButtons() {
        if let accountStatus = accountStatus {
            if accountStatus == .available {
                // User is logged into iCloud
                loginMessageCell.isHidden = true
                resetFromiCloudButton.isEnabled = !appConfiguration.appLocked() && syncEnabledSwitch.isOn && !resetting
                resetFromLocalButton.isEnabled = !appConfiguration.appLocked() && syncEnabledSwitch.isOn && !resetting
                return
            } else if accountStatus == .noAccount {
                // User is not logged into iCloud
                loginMessageCell.isHidden = false
                syncEnabledSwitch.isEnabled = false
                resetFromiCloudButton.isEnabled = false
                resetFromLocalButton.isEnabled = false
                return
            }
        }
        // No iCloud account status info so use default behaviour
        loginMessageCell.isHidden = false
        resetFromiCloudButton.isEnabled = !appConfiguration.appLocked() && syncEnabledSwitch.isOn && !resetting
        resetFromLocalButton.isEnabled = !appConfiguration.appLocked() && syncEnabledSwitch.isOn && !resetting
    }
}
