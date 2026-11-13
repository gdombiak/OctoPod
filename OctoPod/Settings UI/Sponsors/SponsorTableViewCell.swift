import UIKit

class SponsorTableViewCell: UITableViewCell {

    @IBOutlet weak var sponsorNameLabel: UILabel!
    @IBOutlet weak var sponsorLinkButton: UIButton!
    
    var delegate: SponsorTableViewCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        sponsorNameLabel.numberOfLines = 0
        sponsorNameLabel.lineBreakMode = .byWordWrapping
        sponsorNameLabel.adjustsFontForContentSizeCategory = true
        sponsorNameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        sponsorLinkButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        sponsorLinkButton.setContentCompressionResistancePriority(.required, for: .vertical)
    }

    private var applyingNameWidth = false

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !applyingNameWidth else { return }
        let width = sponsorNameLabel.bounds.width
        guard width > 1, abs(sponsorNameLabel.preferredMaxLayoutWidth - width) > 1 else { return }
        applyingNameWidth = true
        sponsorNameLabel.preferredMaxLayoutWidth = width
        applyingNameWidth = false
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    
    @IBAction func sponsorLinkClicked(_ sender: Any) {
        delegate?.sponsorLinkClicked(cell: self)
    }
}
