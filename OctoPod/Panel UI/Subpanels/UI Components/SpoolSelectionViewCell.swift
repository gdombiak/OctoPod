import UIKit

class SpoolSelectionViewCell: UITableViewCell {

    @IBOutlet weak var toolLabel: UILabel!
    @IBOutlet weak var selectionButton: UIButton!
    @IBOutlet weak var usageLabel: UILabel!
    @IBOutlet weak var codeLabel: UILabel!

    var parentVC: SpoolManagerViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        selectionButton.contentHorizontalAlignment = .right
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    @IBAction func changeSelection(_ sender: Any) {
        parentVC.openChangeSelection(cell: self)
    }
}
