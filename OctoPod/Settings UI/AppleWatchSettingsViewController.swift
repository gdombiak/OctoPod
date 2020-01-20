import Foundation
import UIKit

class AppleWatchSettingsViewController: ThemedStaticUITableViewController {
    
    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()
    let watchSessionManager: WatchSessionManager = { return (UIApplication.shared.delegate as! AppDelegate).watchSessionManager }()

    @IBOutlet weak var defaultTextCell: UITableViewCell!
    @IBOutlet weak var lastPingCell: UITableViewCell!
    @IBOutlet weak var lastVarianceCell: UITableViewCell!
    @IBOutlet weak var maxVarianceCell: UITableViewCell!
    
    @IBOutlet weak var defaultTextLabel: UILabel!
    @IBOutlet weak var lastPingLabel: UILabel!
    @IBOutlet weak var lastVarianceLabel: UILabel!
    @IBOutlet weak var maxVarianceLabel: UILabel!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Theme labels
        let theme = Theme.currentTheme()
        let textColor = theme.textColor()
        defaultTextLabel.textColor = textColor
        lastPingLabel.textColor = textColor
        lastVarianceLabel.textColor = textColor
        maxVarianceLabel.textColor = textColor

        refreshSelectedContentType()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section != 0 {
            // Ignore if not selecting Theme
            return
        }
        var selectedContentType: ComplicationContentType.Choice = .defaultText
        if indexPath.row == 1 {
            selectedContentType = .palette2LastPing
        } else if indexPath.row == 2 {
            selectedContentType = .palette2LastVariation
        } else if indexPath.row == 3 {
            selectedContentType = .palette2MaxVariation
        }
        // Update app configuration and inform Apple Watch of new setting
        appConfiguration.complicationContentType(contentType: selectedContentType)
        watchSessionManager.updateComplicationsContentType(contentType: selectedContentType)
        // Refresh table
        viewWillAppear(false)
    }

    fileprivate func refreshSelectedContentType() {
        let contentType = appConfiguration.complicationContentType()
        switch contentType {
        case .defaultText:
            defaultTextCell.accessoryType = .checkmark
            lastPingCell.accessoryType = .none
            lastVarianceCell.accessoryType = .none
            maxVarianceCell.accessoryType = .none
        case .palette2LastPing:
            defaultTextCell.accessoryType = .none
            lastPingCell.accessoryType = .checkmark
            lastVarianceCell.accessoryType = .none
            maxVarianceCell.accessoryType = .none
        case .palette2LastVariation:
            defaultTextCell.accessoryType = .none
            lastPingCell.accessoryType = .none
            lastVarianceCell.accessoryType = .checkmark
            maxVarianceCell.accessoryType = .none
        case .palette2MaxVariation:
            defaultTextCell.accessoryType = .none
            lastPingCell.accessoryType = .none
            lastVarianceCell.accessoryType = .none
            maxVarianceCell.accessoryType = .checkmark
        }
    }
}
