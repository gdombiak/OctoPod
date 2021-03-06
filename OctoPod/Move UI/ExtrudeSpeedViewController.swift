import UIKit

class ExtrudeSpeedViewController: ThemedStaticUITableViewController {

    @IBOutlet weak var speedChoiceControl: UISegmentedControl!
    @IBOutlet weak var customSpeedField: UITextField!
    @IBOutlet weak var proceedButton: UIButton!
    
    var onCompletion: ((Int?) -> Void)!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Set background color of popover and its arrow based on current theme
        let theme = Theme.currentTheme()
        self.popoverPresentationController?.backgroundColor = theme.backgroundColor()
    }

    @IBAction func speedChoiceChanged(_ sender: Any) {
        if isCustomSpeed()  {
            if let value = customSpeedField.text {
                proceedButton.isEnabled = !value.isEmpty
            } else {
                proceedButton.isEnabled = false
            }
            // "Move cursor" to custom speed field
            customSpeedField.becomeFirstResponder()
        } else {
            proceedButton.isEnabled = true
            // Remove cursor from custom field
            customSpeedField.resignFirstResponder()
        }
    }
    
    @IBAction func customSpeedTouched(_ sender: Any) {
        // Make sure that Custom is selected when user clicked on field to enter Speed value
        speedChoiceControl.selectedSegmentIndex = 1
        // Enable/Disable Proceed button based on value
        enableProceedBasedOnCustomSpeed()
    }
    
    @IBAction func customSpeedChanging(_ sender: Any) {
        enableProceedBasedOnCustomSpeed()
    }
    
    @IBAction func proceedClicked(_ sender: Any) {
        if isCustomSpeed() {
            onCompletion(Int(customSpeedField.text!))
        } else {
            onCompletion(nil)
        }
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Table view operations
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 36
    }

    // MARK: - Private functions

    fileprivate func isCustomSpeed() -> Bool {
        return speedChoiceControl.selectedSegmentIndex == 1
    }
    
    fileprivate func enableProceedBasedOnCustomSpeed() {
        if let value = customSpeedField.text {
            proceedButton.isEnabled = !value.isEmpty
            if let speed = Int(value) {
                if speed < 0 {
                    customSpeedField.text = "0"
                } else if speed > 3000 {
                    customSpeedField.text = "3000"
                }
            }
        } else {
            proceedButton.isEnabled = false
        }
    }
}
