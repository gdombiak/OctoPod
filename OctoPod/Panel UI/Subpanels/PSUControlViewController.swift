import UIKit

class PSUControlViewController: ThemedStaticUITableViewController, SubpanelViewController {

    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var powerButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let theme = Theme.currentTheme()
        infoLabel.textColor = theme.labelColor()
    }
    

    // MARK: - SubpanelViewController
    
    func printerSelectedChanged() {
        // TODO Implement THIS
    }
    
    // Notification that OctoPrint state has changed. This may include printer status information
    func currentStateUpdated(event: CurrentStateEvent) {
        // TODO Implement THIS
    }
    
    // MARK: - Button action

    @IBAction func powerButtonPressed(_ sender: Any) {
    }
}
