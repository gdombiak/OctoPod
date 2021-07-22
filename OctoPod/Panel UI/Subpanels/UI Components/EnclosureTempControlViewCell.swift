import UIKit

class EnclosureTempControlViewCell: LabelAndFieldViewCell {

    var parentVC: EnclosureViewController!

    override func fieldValueApplied() {
        if let text = pwmField.text {
            if let value = Int(text) {
                // Simulate that user moved the slider so we execute the action
                parentVC.tempControlChanged(cell: self, temp: value)
            }
        }
    }
    
    override func fieldValueChanged() {
        if let text = pwmField.text {
            if let value = Int(text) {
                // Make sure that value does not go over limit
                if value > 999 {
                    pwmField.text = "999"
                }
                if value < 0 {
                    pwmField.text = "0"
                }
            }
        }
    }
}
