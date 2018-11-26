import UIKit

class SiriViewController: ThemedStaticUITableViewController {

    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()

    @IBOutlet weak var deleteIntentionsButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let theme = Theme.currentTheme()
        deleteIntentionsButton.tintColor = theme.tintColor()
        
        
        checkAppLockStatus()
    }

    @IBAction func deleteIntentionsChanged(_ sender: Any) {
        showConfirm(message: NSLocalizedString("Confirm intentions deletion", comment: ""), yes: { (UIAlertAction) -> Void in
            IntentsDonations.deleteDonatedIntentions()
        }, no: { (UIAlertAction) -> Void in
            // Do nothing
        })
    }
    
    // MARK: - Private functions
    
    fileprivate func checkAppLockStatus() {
        // Do not let user change these settings when app is in locked mode
        deleteIntentionsButton.isEnabled = !appConfiguration.appLocked()
    }

    fileprivate func showConfirm(message: String, yes: @escaping (UIAlertAction) -> Void, no: @escaping (UIAlertAction) -> Void) {
        UIUtils.showConfirm(presenter: self, message: message, yes: yes, no: no)
    }
}
