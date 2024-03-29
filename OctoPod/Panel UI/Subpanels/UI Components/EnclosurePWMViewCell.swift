import UIKit

class EnclosurePWMViewCell: LabelAndFieldViewCell {

    var parentVC: EnclosureViewController!

    override func fieldValueApplied() {
        if let text = pwmField.text {
            if let value = Int(text) {
                // Simulate that user moved the slider so we execute the action
                parentVC.pwmChanged(cell: self, dutyCycle: value)
            }
        }
    }
    
    override func fieldValueChanged() {
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
}
