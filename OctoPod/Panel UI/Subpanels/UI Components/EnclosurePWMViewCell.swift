import UIKit

class EnclosurePWMViewCell: UITableViewCell {

    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var pwmField: UITextField!

    var parentVC: EnclosureViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        addKeyboardButtons(field: pwmField, cancelSelector: #selector(EnclosurePWMViewCell.closeFlowKeyboard), applySelector: #selector(EnclosurePWMViewCell.applyFlowKeyboard))
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    @IBAction func pwmKeyboardChanged(_ sender: Any) {
        if let text = pwmField.text {
            if let value = Int(text) {
                // Make sure that value does not go over limit
                if value > 100 {
                    pwmField.text = "100"
                }
                if value < 0 {
                    pwmField.text = "0"
                }
            }
        }
    }

    @objc func closeFlowKeyboard() {
        pwmField.resignFirstResponder()
        // User cancelled so clean up value
        pwmField.text = ""
    }
    
    @objc func applyFlowKeyboard() {
        pwmField.resignFirstResponder()
        if let text = pwmField.text {
            if let value = Int(text) {
//                // Validate value is within range. We validated max so we now validate min
//                if value < 0 {
//                    // Update field with min value of slider
//                    flowRateField.text = "0"
//                } else {
//                    // Update slider with entered value
//                    flowRateSlider.value = Float(value)
//                }
                // Simulate that user moved the slider so we execute the action
                parentVC.pwmChanged(cell: self, dutyCycle: value)
            }
        }
    }

    // MARK: - Private fuctions
    
    fileprivate func addKeyboardButtons(field: UITextField, cancelSelector: Selector, applySelector: Selector) {
        let numberToolbar: UIToolbar = UIToolbar()
        numberToolbar.barStyle = UIBarStyle.blackTranslucent
        numberToolbar.items=[
            UIBarButtonItem(title: NSLocalizedString("Cancel", comment: ""), style: UIBarButtonItem.Style.plain, target: self, action: cancelSelector),
            UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: self, action: nil),
            UIBarButtonItem(title: NSLocalizedString("Apply", comment: ""), style: UIBarButtonItem.Style.plain, target: self, action: applySelector)
        ]
        numberToolbar.sizeToFit()
        field.inputAccessoryView = numberToolbar
    }
}
