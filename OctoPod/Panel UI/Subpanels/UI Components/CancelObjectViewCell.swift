import UIKit

class CancelObjectViewCell: UITableViewCell {
    
    @IBOutlet weak var objectLabel: UILabel!
    @IBOutlet weak var cancelButton: UIButton!

    var row: Int!

    var cancelObjectViewController: CancelObjectViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    @IBAction func cancelClicked(_ sender: Any) {
        cancelObjectViewController.cancelObject(objectId: row)
    }
}
