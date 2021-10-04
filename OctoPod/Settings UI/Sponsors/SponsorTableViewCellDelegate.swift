import Foundation

protocol SponsorTableViewCellDelegate {
    
    /// User clicked on link to see sponsor information
    func sponsorLinkClicked(cell: SponsorTableViewCell)
}
