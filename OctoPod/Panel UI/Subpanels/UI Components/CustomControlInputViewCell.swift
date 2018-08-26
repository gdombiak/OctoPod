import UIKit

class CustomControlInputViewCell: UITableViewCell {

    @IBOutlet weak var inputLabel: UILabel!
    @IBOutlet weak var inputValueField: UITextField!
    
    var row: Int!

    var executeControlViewController: ExecuteControlViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    @IBAction func valueChanged(_ sender: Any) {
        // Notify parentVC of new value for this Input
        if let text = inputValueField.text {
            executeControlViewController.valueUpdated(row: row, value: text as AnyObject)
        }
   }
}
