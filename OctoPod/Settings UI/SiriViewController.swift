import UIKit
import SafariServices  // Used for opening browser in-app

class SiriViewController: ThemedStaticUITableViewController {

    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()

    @IBOutlet weak var deleteIntentsButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let theme = Theme.currentTheme()
        deleteIntentsButton.tintColor = theme.tintColor()
        
        checkAppLockStatus()
    }

    @IBAction func deleteIntentsChanged(_ sender: Any) {
        showConfirm(message: NSLocalizedString("Confirm intentions deletion", comment: ""), yes: { (UIAlertAction) -> Void in
            IntentsDonations.deleteAllDonatedIntents()
        }, no: { (UIAlertAction) -> Void in
            // Do nothing
        })
    }
    
    // MARK: - Private functions
    
    fileprivate func checkAppLockStatus() {
        // Do not let user change these settings when app is in locked mode
        deleteIntentsButton.isEnabled = !appConfiguration.appLocked()
    }

    fileprivate func showConfirm(message: String, yes: @escaping (UIAlertAction) -> Void, no: @escaping (UIAlertAction) -> Void) {
        UIUtils.showConfirm(presenter: self, message: message, yes: yes, no: no)
    }
}
