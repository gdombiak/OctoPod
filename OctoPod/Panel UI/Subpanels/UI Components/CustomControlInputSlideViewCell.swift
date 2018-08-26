import UIKit

class CustomControlInputSlideViewCell: UITableViewCell {
    
    @IBOutlet weak var inputLabel: UILabel!
    @IBOutlet weak var inputValueField: UITextField!
    @IBOutlet weak var inputValueSlider: UISlider!
    
    var row: Int!
    var steps: Float!

    var executeControlViewController: ExecuteControlViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    @IBAction func sliderChanged(_ sender: Any) {
        let roundedValue = round(inputValueSlider.value / steps) * steps
        inputValueSlider.value = roundedValue
        // Update text field based on slider value
        updateTextField(newValue: roundedValue)
        // Notify parentVC of new value for this Input
        executeControlViewController.valueUpdated(row: row, value: currentValue())
    }
    
    @IBAction func valueChanged(_ sender: Any) {
        if let text = inputValueField.text, let newValue = Float(text) {
            if newValue < inputValueSlider.minimumValue {
                // Make sure that new value is within range
                updateTextField(newValue: inputValueSlider.minimumValue)
            } else if newValue > inputValueSlider.maximumValue {
                // Make sure that new value is within range
                updateTextField(newValue: inputValueSlider.maximumValue)
            }
        } else {
            // If for some reason there is no value then set min value
            updateTextField(newValue: inputValueSlider.minimumValue)
        }
        // Update slider value based on entry field value
        inputValueSlider.value = Float(inputValueField.text!)!
        // Notify parentVC of new value for this Input
        executeControlViewController.valueUpdated(row: row, value: currentValue())
    }
    
    fileprivate func updateTextField(newValue: Float) {
        let isInteger = newValue.truncatingRemainder(dividingBy: 1) == 0
        if isInteger {
            inputValueField.text = String(format: "%.0f", newValue)
        } else {
            inputValueField.text = String(newValue)
        }
    }
    
    fileprivate func currentValue() -> AnyObject {
        let value = inputValueSlider.value
        let isInteger = value.truncatingRemainder(dividingBy: 1) == 0
        if isInteger {
            return Int(value) as AnyObject
        }
        return value as AnyObject
    }
}
