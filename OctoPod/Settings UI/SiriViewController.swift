import UIKit
import SafariServices  // Used for opening browser in-app

class SiriViewController: ThemedStaticUITableViewController {

    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()
    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()

    @IBOutlet weak var deleteIntentsButton: UIButton!
    @IBOutlet weak var regenerateIntentsButton: UIButton!
    @IBOutlet weak var siriIntegrationButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let theme = Theme.currentTheme()
        deleteIntentsButton.tintColor = theme.tintColor()
        regenerateIntentsButton.tintColor = theme.tintColor()
        siriIntegrationButton.tintColor = theme.tintColor()
        
        checkAppLockStatus()
    }

    @IBAction func deleteIntentsChanged(_ sender: Any) {
        showConfirm(message: NSLocalizedString("Confirm intentions deletion", comment: ""), yes: { (UIAlertAction) -> Void in
            IntentsDonations.deleteAllDonatedIntents(done: nil)
        }, no: { (UIAlertAction) -> Void in
            // Do nothing
        })
    }
    
    @IBAction func regenerateIntentChanged(_ sender: Any) {
        showConfirm(message: NSLocalizedString("Confirm intentions regeneration", comment: ""), yes: { (UIAlertAction) -> Void in
            IntentsDonations.deleteAllDonatedIntents(done: { (error: Error?) in
                if error == nil {
                    IntentsDonations.initIntentsForAllPrinters(printerManager: self.printerManager, force: true)
                }
            })
        }, no: { (UIAlertAction) -> Void in
            // Do nothing
        })
    }
    
    @IBAction func siriIntegrationChanged(_ sender: Any) {
        let svc = SFSafariViewController(url: URL(string: "https://github.com/gdombiak/OctoPod/wiki/Siri-integration-with-OctoPod")!)
        self.present(svc, animated: true, completion: nil)
    }
    
    // MARK: - Private functions
    
    fileprivate func checkAppLockStatus() {
        // Do not let user change these settings when app is in locked mode
        deleteIntentsButton.isEnabled = !appConfiguration.appLocked()
        regenerateIntentsButton.isEnabled = !appConfiguration.appLocked()
    }

    fileprivate func showConfirm(message: String, yes: @escaping (UIAlertAction) -> Void, no: @escaping (UIAlertAction) -> Void) {
        UIUtils.showConfirm(presenter: self, message: message, yes: yes, no: no)
    }
}
