import UIKit
import SafariServices  // Used for opening browser in-app

class SupportViewController: ThemedStaticUITableViewController {

    @IBOutlet weak var faqLabel: UILabel!
    @IBOutlet weak var siriIntegrationLabel: UILabel!
    @IBOutlet weak var issuesLabel: UILabel!
    @IBOutlet weak var contributingLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Theme labels
        let theme = Theme.currentTheme()
        faqLabel.textColor = theme.textColor()
        siriIntegrationLabel.textColor = theme.textColor()
        issuesLabel.textColor = theme.textColor()
        contributingLabel.textColor = theme.textColor()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            openBrowser(url: "https://github.com/gdombiak/OctoPod/wiki/FAQ-using-the-app")
        } else if indexPath.row == 1 {
            openBrowser(url: "https://github.com/gdombiak/OctoPod/wiki/Siri-integration-with-OctoPod")
        } else if indexPath.row == 2 {
            openBrowser(url: "https://github.com/gdombiak/OctoPod/issues")
        } else if indexPath.row == 3 {
            openBrowser(url: "https://github.com/gdombiak/OctoPod/blob/master/README.md")
        } else if indexPath.row == 4 {
            // User clicked on Facebook
            let application = UIApplication.shared
            let usersGroupInAppURL = URL(string: "fb://profile?id=671392683736523")!
            let usersGroupInBrowserURL = URL(string: "https://www.facebook.com/groups/octopodprint")!
            if application.canOpenURL(usersGroupInAppURL) {
                // Open FB app and take user to target URL
                application.open(usersGroupInAppURL)
            } else {
                // Open iOS browser and go to target URL
                application.open(usersGroupInBrowserURL)
            }
            // Unselect row so when user comes back it does not appear as selected
            tableView.deselectRow(at: indexPath, animated: false)
        } else if indexPath.row == 5 {
            // User clicked on Twitter
            let application = UIApplication.shared
            let twitterAccountInAppURL = URL(string: "twitter://user?screen_name=OctoPodPrint")!
            let twitterAccountInBrowserURL = URL(string: "https://twitter.com/OctoPodPrint")!
            if application.canOpenURL(twitterAccountInAppURL) {
                // Open Twitter app and take user to target URL
                application.open(twitterAccountInAppURL)
            } else {
                // Open iOS browser and go to target URL
                application.open(twitterAccountInBrowserURL)
            }
            // Unselect row so when user comes back it does not appear as selected
            tableView.deselectRow(at: indexPath, animated: false)
        } else {
            NSLog("SupportViewController - Click on unknown row")
        }
    }
    
    fileprivate func openBrowser(url: String) {
        let svc = SFSafariViewController(url: URL(string: url)!)
        self.present(svc, animated: true, completion: nil)
    }
}
