import UIKit

class EnclosureGPIOViewCell: UITableViewCell {

    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var powerButton: UIButton!

    var isPowerOn: Bool? // nil if unknown
    
    var parentVC: EnclosureViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    func setPowerState(isPowerOn: Bool?) {
        if let on = isPowerOn {
            // Enable power button
            powerButton.isEnabled = !appConfiguration.appLocked() // Enable button only if app is not locked
            powerButton.setImage(UIImage(named: on ? "TPPowerOn" : "TPPowerOff"), for: .normal)
        } else {
            // Disable power button since state is undefined
            powerButton.isEnabled = false
            // Assume power is off so render this image
            powerButton.setImage(UIImage(named: "TPPowerOff"), for: .normal)
        }
        self.isPowerOn = isPowerOn
    }
    
    @IBAction func powerPressed(_ sender: AnyObject) {
        parentVC.powerPressed(cell: self)
    }
}
