import UIKit

class NotRefreshingReasonViewController: UITableViewController {
    
    @IBOutlet weak var reasonLabel: UILabel!
    
    var reason: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Set reason why connection failed
        reasonLabel.text = reason
    }
}
