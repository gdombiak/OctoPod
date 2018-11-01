import UIKit

class ExtrudeSpeedViewController: ThemedStaticUITableViewController {

    @IBOutlet weak var speedChoiceControl: UISegmentedControl!
    @IBOutlet weak var customSpeedField: UITextField!
    @IBOutlet weak var proceedButton: UIButton!
    
    var onCompletion: ((Int?) -> Void)!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func speedChoiceChanged(_ sender: Any) {
        let isCustom = isCustomSpeed()
        customSpeedField.isEnabled = isCustom
        if isCustom  {
            if let value = customSpeedField.text {
                proceedButton.isEnabled = !value.isEmpty
            } else {
                proceedButton.isEnabled = false
            }
        } else {
            proceedButton.isEnabled = true
        }
    }
    
    @IBAction func customSpeedChanging(_ sender: Any) {
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
    
    @IBAction func proceedClicked(_ sender: Any) {
        if isCustomSpeed() {
            onCompletion(Int(customSpeedField.text!))
        } else {
            onCompletion(nil)
        }
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Private functions

    fileprivate func isCustomSpeed() -> Bool {
        return speedChoiceControl.selectedSegmentIndex == 1
    }
    

}
