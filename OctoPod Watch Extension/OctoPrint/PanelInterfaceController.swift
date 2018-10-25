import WatchKit
import Foundation


class PanelInterfaceController: WKInterfaceController {

    @IBOutlet weak var printerStateLabel: WKInterfaceLabel!
    @IBOutlet weak var completionLabel: WKInterfaceLabel!
    @IBOutlet weak var printTimeLeftLabel: WKInterfaceLabel!
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Configure interface objects here.
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
        OctoPrintClient.instance.currentJobInfo { (reply: [String : Any]) in
            // TODO Display error
            DispatchQueue.main.async {
                if let state = reply["state"] as? String {
                    self.printerStateLabel.setText(state)
                }
                if let completion = reply["completion"] as? Double {
                    let progressText = String(format: "%.1f", completion)
                    self.completionLabel.setText("\(progressText)%")
                }
                if let printTimeLeft = reply["printTimeLeft"] as? Int {
                    self.printTimeLeftLabel.setText(self.secondsToTimeLeft(seconds: printTimeLeft))
                }
            }
        }
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

    // MARK: - Private functions
    
    fileprivate func secondsToTimeLeft(seconds: Int) -> String {
        if seconds == 0 {
            return ""
        } else if seconds < 0 {
            // Should never happen but an OctoPrint plugin is returning negative values
            // so return 'Unknown' when this happens
            return NSLocalizedString("Unknown", comment: "ETA is Unknown")
        }
        let duration = TimeInterval(seconds)
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .brief
        formatter.includesApproximationPhrase = true
        formatter.allowedUnits = [ .day, .hour, .minute ]
        return formatter.string(from: duration)!
    }
}
