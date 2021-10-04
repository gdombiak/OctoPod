import UIKit

class SponsorTableViewCell: UITableViewCell {

    @IBOutlet weak var sponsorNameLabel: UILabel!
    @IBOutlet weak var sponsorLinkButton: UIButton!
    
    var delegate: SponsorTableViewCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    
    @IBAction func sponsorLinkClicked(_ sender: Any) {
        delegate?.sponsorLinkClicked(cell: self)
    }
}
