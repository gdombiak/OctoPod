import UIKit

class LabelAndFieldViewCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var pwmField: UITextField!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        addKeyboardButtons(field: pwmField, cancelSelector: #selector(LabelAndFieldViewCell.closeFlowKeyboard), applySelector: #selector(LabelAndFieldViewCell.applyFlowKeyboard))
    }

    @IBAction func pwmKeyboardChanged(_ sender: Any) {
        fieldValueChanged()
    }

    @objc func closeFlowKeyboard() {
        pwmField.resignFirstResponder()
        // User cancelled so clean up value
        pwmField.text = ""
    }
    
    @objc func applyFlowKeyboard() {
        pwmField.resignFirstResponder()
        fieldValueApplied()
    }
    
    // MARK: - Abstract fuctions
    
    /// User clicked on Apply button on keyboard so editing is done and value has been applied
    func fieldValueApplied() {}

    /// User is typing on keyboard and field value is changing. Perform needed validations
    func fieldValueChanged() {}

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
