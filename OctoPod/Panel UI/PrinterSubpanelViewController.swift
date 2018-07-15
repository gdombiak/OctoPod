import UIKit

class PrinterSubpanelViewController: UITableViewController, UIPopoverPresentationControllerDelegate {
    
    enum buttonsScope {
        case all
        case all_except_connect
    }
    
    @IBOutlet weak var printerStatusLabel: UILabel!
    
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var printTimeLabel: UILabel!
    @IBOutlet weak var printTimeLeftLabel: UILabel!
    @IBOutlet weak var printJobButton: UIButton!
    
    @IBOutlet weak var tool0SetTempButton: UIButton!
    @IBOutlet weak var tool0ActualLabel: UILabel!
    @IBOutlet weak var tool0TargetLabel: UILabel!
    @IBOutlet weak var tool0SplitLabel: UILabel!
    
    @IBOutlet weak var tool1Row: UITableViewCell!
    @IBOutlet weak var tool1SetTempButton: UIButton!
    @IBOutlet weak var tool1ActualLabel: UILabel!
    @IBOutlet weak var tool1TargetLabel: UILabel!
    @IBOutlet weak var tool1SplitLabel: UILabel!
    
    @IBOutlet weak var bedSetTempButton: UIButton!
    @IBOutlet weak var bedActualLabel: UILabel!
    @IBOutlet weak var bedTargetLabel: UILabel!
    @IBOutlet weak var bedSplitLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Ugly hack to hide the extra space above the tableView
        tableView.contentInset = UIEdgeInsetsMake(-20, 0, 0, 0);
        
        // Round the corners of the progres bar
        progressView.layer.cornerRadius = 8
        progressView.clipsToBounds = true
        progressView.layer.sublayers![1].cornerRadius = 8
        progressView.subviews[1].clipsToBounds = true
        
        clearValues()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func printerSelectedChanged() {
        clearValues()
    }
    
     // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "set_target_temp_bed" {
            if let controller = segue.destination as? SetTargetTempViewController {
                controller.targetTempScope = SetTargetTempViewController.TargetScope.bed
                controller.popoverPresentationController!.delegate = self
            }
        } else if segue.identifier == "set_target_temp_tool0" {
            if let controller = segue.destination as? SetTargetTempViewController {
                controller.targetTempScope = SetTargetTempViewController.TargetScope.tool0
                controller.popoverPresentationController!.delegate = self
            }
        } else if segue.identifier == "set_target_temp_tool1" {
            if let controller = segue.destination as? SetTargetTempViewController {
                controller.targetTempScope = SetTargetTempViewController.TargetScope.tool1
                controller.popoverPresentationController!.delegate = self
            }
        } else if segue.identifier == "print_job_info" {
            segue.destination.popoverPresentationController!.delegate = self
        }
    }
    
    // MARK: - Notifications from Main Panel Controller

    func currentStateUpdated(event: CurrentStateEvent) {
        DispatchQueue.main.async {
            if let state = event.state {
                self.printerStatusLabel.text = state
            }
            
            if let progress = event.progressCompletion {
                let progressText = String(format: "%.1f", progress)
                self.progressLabel.text = "\(progressText)%"
                self.progressView.progress = Float(progressText)! / 100  // Convert Float from String to prevent weird behaviors
                self.printJobButton.isEnabled = progress > 0
            }
            
            if let seconds = event.progressPrintTime {
                self.printTimeLabel.text = self.secondsToPrintTime(seconds: seconds)
            }

            if let seconds = event.progressPrintTimeLeft {
                self.printTimeLeftLabel.text = self.secondsToTimeLeft(seconds: seconds)
            } else if event.progressPrintTime != nil {
                self.printTimeLeftLabel.text = "Still stabilizing..."
            }

            if let tool0Actual = event.tool0TempActual {
                self.tool0ActualLabel.text = "\(String(format: "%.1f", tool0Actual)) C"
                self.tool0SplitLabel.isHidden = false
            }
            if let tool0Target = event.tool0TempTarget {
                self.tool0TargetLabel.text = "\(String(format: "%.0f", tool0Target)) C"
                self.tool0SplitLabel.isHidden = false
            }

            if let tool1Actual = event.tool1TempActual {
                self.tool1ActualLabel.text = "\(String(format: "%.1f", tool1Actual)) C"
                self.tool1Row.isHidden = false
            }
            if let tool1Target = event.tool1TempTarget {
                self.tool1TargetLabel.text = "\(String(format: "%.0f", tool1Target)) C"
                self.tool1Row.isHidden = false
            }
            
            if let bedActual = event.bedTempActual {
                self.bedActualLabel.text = "\(String(format: "%.1f", bedActual)) C"
                self.bedSplitLabel.isHidden = false
            }
            if let bedTarget = event.bedTempTarget {
                self.bedTargetLabel.text = "\(String(format: "%.0f", bedTarget)) C"
                self.bedSplitLabel.isHidden = false
            }
            
            if let disconnected = event.closedOrError {
                self.bedSetTempButton.isEnabled = !disconnected
                self.tool0SetTempButton.isEnabled = !disconnected
                self.tool1SetTempButton.isEnabled = !disconnected
            }
        }
    }
    
    // MARK: - UIPopoverPresentationControllerDelegate
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }

    // MARK: - Private functions
    
    // Converts number of seconds into a string that represents time (e.g. 23h 10m)
    func secondsToPrintTime(seconds: Int) -> String {
        let duration = TimeInterval(seconds)
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .brief
        formatter.allowedUnits = [ .day, .hour, .minute, .second ]
        formatter.zeroFormattingBehavior = [ .default ]
        return formatter.string(from: duration)!
    }
    
    func secondsToTimeLeft(seconds: Int) -> String {
        if seconds == 0 {
            return ""
        }
        let duration = TimeInterval(seconds)
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .brief
        formatter.includesApproximationPhrase = true
        formatter.allowedUnits = [ .day, .hour, .minute ]
        return formatter.string(from: duration)!
    }
    
    fileprivate func clearValues() {
        DispatchQueue.main.async {
            self.printerStatusLabel.text = "Offline"

            self.progressView.progress = 0
            self.progressLabel.text = "0%"
            self.printTimeLabel.text = ""
            self.printTimeLeftLabel.text = ""
            self.printJobButton.isEnabled = false
            
            self.tool0ActualLabel.text = ""
            self.tool0TargetLabel.text = ""
            self.tool0SplitLabel.isHidden = true
            // Hide second hotend unless printe reports that it has one
            self.tool1Row.isHidden = true
            
            self.bedActualLabel.text = "            " // Use empty spaces to position Bed label in a good place
            self.bedTargetLabel.text = "        " // Use empty spaces to position Bed label in a good place
            self.bedSplitLabel.isHidden = true
            
            // Disable these buttons
            self.bedSetTempButton.isEnabled = false
            self.tool0SetTempButton.isEnabled = false
            self.tool1SetTempButton.isEnabled = false
        }
    }
}
