import UIKit

class TPLinkSmartplugTableViewCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var powerButton: UIButton!

    var ip: String! // IP Address configured for the TPLink Smartplug
    
    var isPowerOn: Bool? // nil if unknown
    
    var parentVC: TPLinkSmartplugViewController!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    func setPowerState(isPowerOn: Bool?) {
        if let on = isPowerOn {
            // Enable power button
            powerButton.isEnabled = true
            powerButton.setImage(UIImage(named: on ? "TPPowerOff" : "TPPowerOn"), for: .normal)
        } else {
            // Disable power button
            powerButton.isEnabled = false
            // Assume power is off so render this image
            powerButton.setImage(UIImage(named: "TPPowerOn"), for: .normal)
        }
        self.isPowerOn = isPowerOn
    }
    
    @IBAction func powerPressed(_ sender: AnyObject) {
        parentVC.powerPressed(cell: self)
    }
    
}
