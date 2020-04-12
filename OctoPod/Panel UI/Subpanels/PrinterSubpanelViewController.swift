import UIKit
import StoreKit  // Import for rating app

class PrinterSubpanelViewController: ThemedStaticUITableViewController, UIPopoverPresentationControllerDelegate, SubpanelViewController, OctoPrintPluginsDelegate {
    
    private static let RATE_APP = "PANEL_RATE_APP"
    private static let TOOLTIP_PRINT_INFO = "PANEL_TOOLTIP_PRINT_INFO"
    private static let TOOLTIP_TEMP_TOOL = "PANEL_TOOLTIP_TEMP_TOOL"
    private static let TOOLTIP_TEMP_BED = "PANEL_TOOLTIP_TEMP_BED"

    enum buttonsScope {
        case all
        case all_except_connect
    }
    
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()
    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()

    @IBOutlet weak var printedTextLabel: UILabel!
    @IBOutlet weak var printTimeTextLabel: UILabel!
    @IBOutlet weak var printTimeLeftTextLabel: UILabel!
    @IBOutlet weak var printEstimatedCompletionTextLabel: UILabel!
    @IBOutlet weak var printerStatusTextLabel: UILabel!
    @IBOutlet weak var tool0TitleLabel: UILabel!
    @IBOutlet weak var bedTextLabel: UILabel!

    @IBOutlet weak var printerStatusLabel: UILabel!
    
    @IBOutlet weak var currentPrintDetailsRow: UITableViewCell!
    @IBOutlet weak var currentPrintActionsRow: UITableViewCell!
    @IBOutlet weak var printingFileLabel: UILabel!
    @IBOutlet weak var printButton: UIButton!
    @IBOutlet weak var restartButton: UIButton!
    @IBOutlet weak var pauseButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var resumeButton: UIButton!
    
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var printTimeLabel: UILabel!
    @IBOutlet weak var printTimeLeftLabel: UILabel!
    @IBOutlet weak var printEstimatedCompletionLabel: UILabel!
    
    @IBOutlet weak var currentHeightRow: UITableViewCell!
    @IBOutlet weak var currentHeightTextLabel: UILabel!
    @IBOutlet weak var currentHeightLabel: UILabel!
    @IBOutlet weak var layerInfoRow: UITableViewCell!
    @IBOutlet weak var layerTextLabel: UILabel!
    @IBOutlet weak var layerNotificationsButton: UIButton!
    @IBOutlet weak var layerLabel: UILabel!
    
    @IBOutlet weak var toolRow0: UITableViewCell!
    @IBOutlet weak var tool0SetTempButton: UIButton!
    @IBOutlet weak var tool0ActualLabel: UILabel!
    @IBOutlet weak var tool0TargetLabel: UILabel!
    @IBOutlet weak var tool0SplitLabel: UILabel!
    
    @IBOutlet weak var toolRow1: UITableViewCell!
    @IBOutlet weak var tool1TitleLabel: UILabel!
    @IBOutlet weak var tool1TitleConstraint: NSLayoutConstraint!
    @IBOutlet weak var tool1SetTempButton: UIButton!
    @IBOutlet weak var tool1ActualLabel: UILabel!
    @IBOutlet weak var tool1TargetLabel: UILabel!
    @IBOutlet weak var tool1SplitLabel: UILabel!
    @IBOutlet weak var chamberTitleLabel: UILabel!
    @IBOutlet weak var chamberSetTempButton: UIButton!
    @IBOutlet weak var chamberActualLabel: UILabel!
    @IBOutlet weak var chamberTargetLabel: UILabel!
    @IBOutlet weak var chamberSplitLabel: UILabel!

    @IBOutlet weak var toolRow2: UITableViewCell!
    @IBOutlet weak var tool2TitleLabel: UILabel!
    @IBOutlet weak var tool2TitleConstraint: NSLayoutConstraint!
    @IBOutlet weak var tool2SetTempButton: UIButton!
    @IBOutlet weak var tool2ActualLabel: UILabel!
    @IBOutlet weak var tool2TargetLabel: UILabel!
    @IBOutlet weak var tool2SplitLabel: UILabel!
    @IBOutlet weak var tool3TitleLabel: UILabel!
    @IBOutlet weak var tool3SetTempButton: UIButton!
    @IBOutlet weak var tool3ActualLabel: UILabel!
    @IBOutlet weak var tool3TargetLabel: UILabel!
    @IBOutlet weak var tool3SplitLabel: UILabel!

    @IBOutlet weak var toolRow3: UITableViewCell!
    @IBOutlet weak var tool4TitleLabel: UILabel!
    @IBOutlet weak var tool4TitleConstraint: NSLayoutConstraint!
    @IBOutlet weak var tool4SetTempButton: UIButton!
    @IBOutlet weak var tool4ActualLabel: UILabel!
    @IBOutlet weak var tool4TargetLabel: UILabel!
    @IBOutlet weak var tool4SplitLabel: UILabel!

    @IBOutlet weak var bedSetTempButton: UIButton!
    @IBOutlet weak var bedActualLabel: UILabel!
    @IBOutlet weak var bedTargetLabel: UILabel!
    @IBOutlet weak var bedSplitLabel: UILabel!
    
    var lastKnownPrintFile: PrintFile?
    
    private var tool0ActualLabelIsVisibile = true
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Round the corners of the progres bar
        progressView.layer.cornerRadius = 8
        progressView.clipsToBounds = true
        progressView.layer.sublayers![1].cornerRadius = 8
        progressView.subviews[1].clipsToBounds = true
        
        clearValues()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        themeLabels()
        
        // Listen to changes to OctoPrint Plugin messages
        octoprintClient.octoPrintPluginsDelegates.append(self)

        checkTempLabelVisibility()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Stop listening to changes to OctoPrint Plugin messages
        octoprintClient.remove(octoPrintPluginsDelegate: self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Table view operations

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 36
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            if (indexPath.row == 0 || indexPath.row == 1) && currentPrintDetailsRow.isHidden {
                return 0
            } else if indexPath.row == 6 && currentHeightRow.isHidden {
                return 0
            } else if indexPath.row == 7 && layerInfoRow.isHidden {
                return 0
            }
        }
        return super.tableView(tableView, heightForRowAt: indexPath)
    }

    // MARK: - UIScrollViewDelegate

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        checkTempLabelVisibility()
    }
    
    // MARK: - OctoPrintPluginsDelegate
     
    func pluginMessage(plugin: String, data: NSDictionary) {
        if plugin == Plugins.DISPLAY_LAYER_PROGRESS {
            self.updateLayerPlugin(plugin, data: data)
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "set_target_temp_bed" {
            if let controller = segue.destination as? SetTargetTempViewController {
                controller.targetTempScope = SetTargetTempViewController.TargetScope.bed
                controller.popoverPresentationController!.delegate = self
                // Make the popover appear at the middle of the button
                segue.destination.popoverPresentationController!.sourceRect = CGRect(x: bedSetTempButton.frame.size.width/2, y: 0 , width: 0, height: 0)
            }
        } else if segue.identifier == "bed_tooltip" {
            segue.destination.popoverPresentationController!.delegate = self
            // Make the popover appear at the middle of the button
            segue.destination.popoverPresentationController!.sourceRect = CGRect(x: bedSetTempButton.frame.size.width/2, y: 0 , width: 0, height: 0)
        } else if segue.identifier == "set_target_temp_tool0" {
            if let controller = segue.destination as? SetTargetTempViewController {
                controller.targetTempScope = SetTargetTempViewController.TargetScope.tool0
                controller.popoverPresentationController!.delegate = self
                // Make the popover appear at the middle of the button
                segue.destination.popoverPresentationController!.sourceRect = CGRect(x: tool0SetTempButton.frame.size.width/2, y: 0 , width: 0, height: 0)
            }
        } else if segue.identifier == "tool0_tooltip" {
            segue.destination.popoverPresentationController!.delegate = self
            // Make the popover appear at the middle of the button
            segue.destination.popoverPresentationController!.sourceRect = CGRect(x: tool0SetTempButton.frame.size.width/2, y: 0 , width: 0, height: 0)
        } else if segue.identifier == "set_target_temp_tool1" {
            if let controller = segue.destination as? SetTargetTempViewController {
                controller.targetTempScope = SetTargetTempViewController.TargetScope.tool1
                controller.popoverPresentationController!.delegate = self
                // Make the popover appear at the middle of the button
                segue.destination.popoverPresentationController!.sourceRect = CGRect(x: tool1SetTempButton.frame.size.width/2, y: 0 , width: 0, height: 0)
            }
        } else if segue.identifier == "chamber_tooltip" {
            segue.destination.popoverPresentationController!.delegate = self
            // Make the popover appear at the middle of the button
            segue.destination.popoverPresentationController!.sourceRect = CGRect(x: chamberSetTempButton.frame.size.width/2, y: 0 , width: 0, height: 0)
        } else if segue.identifier == "set_target_temp_chamber" {
            if let controller = segue.destination as? SetTargetTempViewController {
                controller.targetTempScope = SetTargetTempViewController.TargetScope.chamber
                controller.popoverPresentationController!.delegate = self
                // Make the popover appear at the middle of the button
                segue.destination.popoverPresentationController!.sourceRect = CGRect(x: chamberSetTempButton.frame.size.width/2, y: 0 , width: 0, height: 0)
            }
        } else if segue.identifier == "set_target_temp_tool2" {
            if let controller = segue.destination as? SetTargetTempViewController {
                controller.targetTempScope = SetTargetTempViewController.TargetScope.tool2
                controller.popoverPresentationController!.delegate = self
                // Make the popover appear at the middle of the button
                segue.destination.popoverPresentationController!.sourceRect = CGRect(x: tool2SetTempButton.frame.size.width/2, y: 0 , width: 0, height: 0)
            }
        } else if segue.identifier == "set_target_temp_tool3" {
            if let controller = segue.destination as? SetTargetTempViewController {
                controller.targetTempScope = SetTargetTempViewController.TargetScope.tool3
                controller.popoverPresentationController!.delegate = self
                // Make the popover appear at the middle of the button
                segue.destination.popoverPresentationController!.sourceRect = CGRect(x: tool3SetTempButton.frame.size.width/2, y: 0 , width: 0, height: 0)
            }
        } else if segue.identifier == "layer_notifications" {
            if let controller = segue.destination as? LayerNotificationsViewController {
                controller.popoverPresentationController!.delegate = self
            }
        }
    }
    
    // MARK: - SubpanelViewController

    func printerSelectedChanged() {
        clearValues()
    }
    
    func currentStateUpdated(event: CurrentStateEvent) {
        // Check if we should prompt user to rate app
        checkRateApp(event: event)
        
        DispatchQueue.main.async {
            var reloadTable = false
            
            if let state = event.state {
                self.printerStatusLabel.text = state
            }
            
            if let printFile = event.printFile {
                if self.printingFileLabel.text != printFile.name {
                    self.printingFileLabel.text = printFile.name
                    self.currentPrintDetailsRow.isHidden = false
                    reloadTable = true
                }
            } else {
                // Hide print job information (and action buttons) only if not printing and there is no print info available
                // Printing and no info available may happen when receiving PrinterStateChanged events
                if self.printingFileLabel.text != "" && event.printing != true {
                    self.printingFileLabel.text = ""
                    self.currentPrintDetailsRow.isHidden = true
                    reloadTable = true
                }
            }
            self.lastKnownPrintFile = event.printFile
            self.refrechCurrentPrintButtons(event: event)

            if let progress = event.progressCompletion {
                let progressText = String(format: "%.1f", progress)
                self.progressLabel.text = "\(progressText)%"
                self.progressView.setProgress(Float(progressText)! / 100, animated: true) // Convert Float from String to prevent weird behaviors
            }
            
            if let seconds = event.progressPrintTime {
                self.printTimeLabel.text = self.secondsToPrintTime(seconds: seconds)
            }

            if let seconds = event.progressPrintTimeLeft {
                self.printTimeLeftLabel.text = UIUtils.secondsToTimeLeft(seconds: seconds, includesApproximationPhrase: true, ifZero: "")
                self.printEstimatedCompletionLabel.text = UIUtils.secondsToETA(seconds: seconds)
            } else if event.progressPrintTime != nil {
                self.printTimeLeftLabel.text = NSLocalizedString("Still stabilizing", comment: "Print time is being calculated")
                self.printEstimatedCompletionLabel.text = ""
            }
            
            if let printing = event.printing, let paused = event.paused, let pausing = event.pausing {
                if let printer = self.printerManager.getDefaultPrinter() {
                    self.layerNotificationsButton.isEnabled = (printing || paused || pausing) && printer.octopodPluginInstalled  // Cell will be hidden unless DisplayLayerProgress plugin is installed
                }
            }

            if let tool0Actual = event.tool0TempActual {
                self.tool0ActualLabel.text = "\(String(format: "%.1f", tool0Actual)) C"
                self.tool0SplitLabel.isHidden = false
            }
            if let tool0Target = event.tool0TempTarget {
                self.tool0TargetLabel.text = "\(String(format: "%.0f", tool0Target)) C"
                self.tool0SplitLabel.isHidden = false
            }

            if let toolActual = event.tool1TempActual {
                self.tool1ActualLabel.text = "\(String(format: "%.1f", toolActual)) C"
                self.state(view: self.tool1ActualLabel, enable: true)
                self.state(view: self.tool1SplitLabel, enable: true)
                self.state(view: self.tool1TitleLabel, enable: true)
                self.tool1TitleConstraint?.isActive = true
                self.tool1SetTempButton.isEnabled = true
                self.toolRow1.isHidden = false
            }
            if let toolTarget = event.tool1TempTarget {
                self.tool1TargetLabel.text = "\(String(format: "%.0f", toolTarget)) C"
                self.state(view: self.tool1TargetLabel, enable: true)
                self.toolRow1.isHidden = false
            }
            
            if let chamberActual = event.chamberTempActual {
                self.chamberActualLabel.text = "\(String(format: "%.1f", chamberActual)) C"
                self.state(view: self.chamberActualLabel, enable: true)
                self.state(view: self.chamberSplitLabel, enable: true)
                self.state(view: self.chamberTitleLabel, enable: true)
                self.chamberSetTempButton.isEnabled = true
                self.toolRow1.isHidden = false
            }
            if let chamberTarget = event.chamberTempTarget {
                self.chamberTargetLabel.text = "\(String(format: "%.0f", chamberTarget)) C"
                self.state(view: self.chamberTargetLabel, enable: true)
                self.toolRow1.isHidden = false
            }
            
            if let toolActual = event.tool2TempActual {
                self.tool2ActualLabel.text = "\(String(format: "%.1f", toolActual)) C"
                self.state(view: self.tool2ActualLabel, enable: true)
                self.state(view: self.tool2SplitLabel, enable: true)
                self.state(view: self.tool2TitleLabel, enable: true)
                self.tool2TitleConstraint?.isActive = true
                self.tool2SetTempButton.isEnabled = true
                self.toolRow2.isHidden = false
            }
            if let toolTarget = event.tool2TempTarget {
                self.tool2TargetLabel.text = "\(String(format: "%.0f", toolTarget)) C"
                self.state(view: self.tool2TargetLabel, enable: true)
                self.toolRow2.isHidden = false
            }
            
            if let toolActual = event.tool3TempActual {
                self.tool3ActualLabel.text = "\(String(format: "%.1f", toolActual)) C"
                self.state(view: self.tool3ActualLabel, enable: true)
                self.state(view: self.tool3SplitLabel, enable: true)
                self.state(view: self.tool3TitleLabel, enable: true)
                self.tool3SetTempButton.isEnabled = true
                self.toolRow2.isHidden = false
            }
            if let toolTarget = event.tool3TempTarget {
                self.tool3TargetLabel.text = "\(String(format: "%.0f", toolTarget)) C"
                self.state(view: self.tool3TargetLabel, enable: true)
                self.toolRow2.isHidden = false
            }
            
            if let toolActual = event.tool4TempActual {
                self.tool4ActualLabel.text = "\(String(format: "%.1f", toolActual)) C"
                self.state(view: self.tool4ActualLabel, enable: true)
                self.state(view: self.tool4SplitLabel, enable: true)
                self.state(view: self.tool4TitleLabel, enable: true)
                self.tool4TitleConstraint?.isActive = true
                self.tool4SetTempButton.isEnabled = true
                self.toolRow3.isHidden = false
            }
            if let toolTarget = event.tool4TempTarget {
                self.tool4TargetLabel.text = "\(String(format: "%.0f", toolTarget)) C"
                self.state(view: self.tool4TargetLabel, enable: true)
                self.toolRow3.isHidden = false
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
                if disconnected {
                    self.tool1SetTempButton.isEnabled = false
                    self.chamberSetTempButton.isEnabled = false
                    self.tool2SetTempButton.isEnabled = false
                    self.tool3SetTempButton.isEnabled = false
                    self.tool4SetTempButton.isEnabled = false
                }

                self.presentToolTip(tooltipKey: PrinterSubpanelViewController.TOOLTIP_TEMP_BED, segueIdentifier: "bed_tooltip", button: self.bedSetTempButton)
                self.presentToolTip(tooltipKey: PrinterSubpanelViewController.TOOLTIP_TEMP_TOOL, segueIdentifier: "tool0_tooltip", button: self.tool0SetTempButton)
            }
            
            if reloadTable && self.view.window != nil {
                // Force to recalculate rows height since cells may be visible
                self.tableView.beginUpdates()
                self.tableView.endUpdates()
                self.checkTempLabelVisibility()
            }
        }
    }
    
    func position() -> Int {
        return 0
    }

    // MARK: - UIPopoverPresentationControllerDelegate
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }
    
    // We need to add this so it works on iPhone plus in landscape mode
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }

    // MARK: - Print Action Buttons

    @IBAction func restartJob(_ sender: Any) {
        showConfirm(message: NSLocalizedString("Do you want to restart print job from the beginning?", comment: ""), yes: { (UIAlertAction) in
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            self.octoprintClient.restartCurrentJob { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                if requested {
                    generator.notificationOccurred(.success)
                } else {
                    NSLog("Error requesting to restart current job: \(String(describing: error?.localizedDescription)). Http response: \(response.statusCode)")
                    self.showAlert(NSLocalizedString("Job", comment: ""), message: NSLocalizedString("Notify failed restart job", comment: ""))
                }
            }
        }, no: { (UIAlertAction) -> Void in
            // Do nothing
        })
        if let printer = printerManager.getDefaultPrinter() {
            IntentsDonations.donateRestartJob(printer: printer)
        }
    }
    
    @IBAction func pauseJob(_ sender: Any) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        self.octoprintClient.pauseCurrentJob { (requested: Bool, error: Error?, response: HTTPURLResponse) in
            if requested {
                generator.notificationOccurred(.success)
            } else {
                NSLog("Error requesting to pause current job: \(String(describing: error?.localizedDescription)). Http response: \(response.statusCode)")
                self.showAlert(NSLocalizedString("Job", comment: ""), message: NSLocalizedString("Notify failed pause job", comment: ""))
            }
        }
        if let printer = printerManager.getDefaultPrinter() {
            IntentsDonations.donatePauseJob(printer: printer)
        }
    }
    
    @IBAction func cancelJob(_ sender: Any) {
        showConfirm(message: NSLocalizedString("Do you want to cancel job?", comment: ""), yes: { (UIAlertAction) in
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            self.octoprintClient.cancelCurrentJob { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                if requested {
                    generator.notificationOccurred(.success)
                } else {
                    NSLog("Error requesting to cancel current job: \(String(describing: error?.localizedDescription)). Http response: \(response.statusCode)")
                    self.showAlert(NSLocalizedString("Job", comment: ""), message: NSLocalizedString("Notify failed cancel job", comment: ""))
                }
            }
        }, no: { (UIAlertAction) -> Void in
            // Do nothing
        })
        if let printer = printerManager.getDefaultPrinter() {
            IntentsDonations.donateCancelJob(printer: printer)
        }
    }
    
    @IBAction func printJob(_ sender: Any) {
        if let lastFile = lastKnownPrintFile {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            self.octoprintClient.printFile(origin: lastFile.origin!, path: lastFile.path!) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                if requested {
                    generator.notificationOccurred(.success)
                } else {
                    NSLog("Error requesting to reprint file: \(String(describing: error?.localizedDescription)). Http response: \(response.statusCode)")
                    self.showAlert(NSLocalizedString("Job", comment: ""), message: NSLocalizedString("Notify failed print job again", comment: ""))
                }
            }
        }
    }
    
    @IBAction func resumeJob(_ sender: Any) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        self.octoprintClient.resumeCurrentJob { (requested: Bool, error: Error?, response: HTTPURLResponse) in
            if requested {
                generator.notificationOccurred(.success)
            } else {
                NSLog("Error requesting to resume current job: \(String(describing: error?.localizedDescription)). Http response: \(response.statusCode)")
                self.showAlert(NSLocalizedString("Job", comment: ""), message: NSLocalizedString("Notify failed resume job", comment: ""))
            }
        }
        if let printer = printerManager.getDefaultPrinter() {
            IntentsDonations.donateResumeJob(printer: printer)
        }
    }

    // MARK: - Rate app - Private functions

    // Ask user to rate app. We will ask a maximum of 3 times and only after a job is 100% done.
    // We will ask when job #3, #10 or #30 are done. Only for iOS 10.3 or newer installations
    fileprivate func checkRateApp(event: CurrentStateEvent) {
        let firstAsk = 2
        let secondAsk = 9
        let thirdAsk = 29
        if let progress = event.progressCompletion {
            // Ask users to rate the app only when print job was completed (and after X number of jobs were done)
            if progress == 100 && progressView.progress < 1 {
                let defaults = UserDefaults.standard
                let counter = defaults.integer(forKey: PrinterSubpanelViewController.RATE_APP)
                if counter > thirdAsk {
                    // Stop asking user to rate app
                    return
                }
                if counter == firstAsk || counter == secondAsk || counter == thirdAsk {
                    // Prompt user to rate the app
                    // Only prompt to rate the app if device has iOS 10.3 or later
                    // Not many people use older than 10.3 based on App Store Connect so only implementing this
                    if #available(iOS 10.3, *) {
                        // Wait 2 seconds before prompting so UI can refresh progress
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            SKStoreReviewController.requestReview()
                        }
                    }
                }
                // Increment count
                defaults.set(counter + 1, forKey: PrinterSubpanelViewController.RATE_APP)
            }
        }
    }
    
    // MARK: - Private functions
    
    fileprivate func refrechCurrentPrintButtons(event: CurrentStateEvent) {
        if let pausing = event.pausing, pausing {
            // We are pausing so show Print (disabled), Pause (disabled) and Cancel (disabled)
            self.printButton.isHidden = false
            self.printButton.isEnabled = false
            self.pauseButton.isHidden = false
            self.pauseButton.isEnabled = false
            self.cancelButton.isHidden = false
            self.cancelButton.isEnabled = false

            self.restartButton.isHidden = true
            self.resumeButton.isHidden = true
        } else if let cancelling = event.cancelling, cancelling {
            // We are cancelling so show Print (disabled), Pause (disabled) and Cancel (disabled)
            self.printButton.isHidden = false
            self.printButton.isEnabled = false
            self.pauseButton.isHidden = false
            self.pauseButton.isEnabled = false
            self.cancelButton.isHidden = false
            self.cancelButton.isEnabled = false

            self.restartButton.isHidden = true
            self.resumeButton.isHidden = true
        } else if let printing = event.printing, printing {
            // We are printing so show Print (disabled), Pause and Cancel
            self.printButton.isHidden = false
            self.printButton.isEnabled = false
            self.pauseButton.isHidden = false
            self.pauseButton.isEnabled = !appConfiguration.appLocked()
            self.cancelButton.isHidden = false
            self.cancelButton.isEnabled = !appConfiguration.appLocked()

            self.restartButton.isHidden = true
            self.resumeButton.isHidden = true
        } else if let paused = event.paused, paused {
            // We are paused so offer Restart, Resume and Cancel
            self.restartButton.isHidden = false
            self.restartButton.isEnabled = !appConfiguration.appLocked()
            self.resumeButton.isHidden = false
            self.resumeButton.isEnabled = !appConfiguration.appLocked()
            self.cancelButton.isHidden = false
            self.cancelButton.isEnabled = !appConfiguration.appLocked()

            self.pauseButton.isHidden = true
            self.printButton.isHidden = true
        } else if let printFile = event.printFile {
            // We are not printing so show Print (disabled?), Pause (disabled) and Cancel (disabled)
            self.printButton.isHidden = false
            self.printButton.isEnabled = printFile.name != nil && !appConfiguration.appLocked()
            self.pauseButton.isHidden = false
            self.pauseButton.isEnabled = false
            self.cancelButton.isHidden = false
            self.cancelButton.isEnabled = false

            self.restartButton.isHidden = true
            self.resumeButton.isHidden = true
        }
    }
    
    fileprivate func updateLayerPlugin(_ plugin: String, data: NSDictionary) {
        if plugin == Plugins.DISPLAY_LAYER_PROGRESS {
            if let totalLayer = data["totalLayer"] as? String, let currentLayer = data["currentLayer"] as? String, let currentHeight = data["currentHeightFormatted"] as? String, let totalHeight = data["totalHeightFormatted"] as? String {
                // Refresh UI
                DispatchQueue.main.async {
                    if self.currentHeightRow.isHidden || self.layerInfoRow.isHidden {
                        self.layerInfoRow.isHidden = false
                        self.currentHeightRow.isHidden = false
                        // Force to recalculate rows height since cell is no longer hidden
                        self.tableView.beginUpdates()
                        self.tableView.endUpdates()
                    }
                    self.currentHeightLabel.text = "\(currentHeight) / \(totalHeight)"
                    self.layerLabel.text = "\(currentLayer) / \(totalLayer)"
                }
            }
        } else {
            NSLog("Unknown layer info plugin: \(plugin)")
        }
    }
    
    /// Converts number of seconds into a string that represents time (e.g. 23h 10m)
    func secondsToPrintTime(seconds: Int) -> String {
        let duration = TimeInterval(seconds)
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .brief
        formatter.allowedUnits = [ .day, .hour, .minute, .second ]
        formatter.zeroFormattingBehavior = [ .default ]
        return formatter.string(from: duration)!
    }
    
    fileprivate func presentToolTip(tooltipKey: String, segueIdentifier: String, button: UIButton) {
        let tooltipShown = UserDefaults.standard.bool(forKey: tooltipKey)
        let viewShown = view.window != nil
        if viewShown && button.isEnabled && !tooltipShown && self.presentedViewController == nil {
            UserDefaults.standard.set(true, forKey: tooltipKey)
            self.performSegue(withIdentifier: segueIdentifier, sender: self)
        }
    }
    
    fileprivate func clearValues() {
        DispatchQueue.main.async {
            self.printerStatusLabel.text = NSLocalizedString("Offline", comment: "Printer is Offline")
            
            self.currentPrintDetailsRow.isHidden = true
            self.printingFileLabel.text = ""

            self.printButton.isHidden = false
            self.printButton.isEnabled = false
            self.restartButton.isHidden = true
            self.pauseButton.isHidden = true
            self.cancelButton.isHidden = true
            self.resumeButton.isHidden = true

            self.progressView.setProgress(0, animated: false)
            self.progressLabel.text = "0%"
            self.printTimeLabel.text = ""
            self.printTimeLeftLabel.text = ""
            self.printEstimatedCompletionLabel.text = ""
            
            self.currentHeightRow.isHidden = true   // Hide layer cell until we receive info that needs to be displayed. Comes from plugins, not OctoPrint itself
            self.currentHeightLabel.text = ""
            self.layerInfoRow.isHidden = true   // Hide layer cell until we receive info that needs to be displayed. Comes from plugins, not OctoPrint itself
            self.layerNotificationsButton.isEnabled = false  // Disable layer notifications button until print job is running
            self.layerLabel.text = ""
            
            self.tool0ActualLabel.text = " " // Use empty space to position Extruder label in a good place
            self.tool0TargetLabel.text = ""
            self.tool0SplitLabel.isHidden = true
            // Hide 2nd,3rd,4th,5th extruders and chamber row unless printer reports info
            self.toolRow1.isHidden = true
            self.toolRow2.isHidden = true
            self.toolRow3.isHidden = true
            // Disable tool1 info
            self.state(view: self.tool1ActualLabel, enable: false)
            self.state(view: self.tool1TargetLabel, enable: false)
            self.state(view: self.tool1SplitLabel, enable: false)
            self.state(view: self.tool1TitleLabel, enable: false)
            self.tool1TitleConstraint?.isActive = false
            self.tool1SetTempButton.isEnabled = false
            // Disable chamber info
            self.state(view: self.chamberActualLabel, enable: false)
            self.state(view: self.chamberTargetLabel, enable: false)
            self.state(view: self.chamberSplitLabel, enable: false)
            self.state(view: self.chamberTitleLabel, enable: false)
            self.chamberSetTempButton.isEnabled = false
            // Disable tool2 info
            self.state(view: self.tool2ActualLabel, enable: false)
            self.state(view: self.tool2TargetLabel, enable: false)
            self.state(view: self.tool2SplitLabel, enable: false)
            self.state(view: self.tool2TitleLabel, enable: false)
            self.tool2TitleConstraint?.isActive = false
            self.tool2SetTempButton.isEnabled = false
            // Disable tool3 info
            self.state(view: self.tool3ActualLabel, enable: false)
            self.state(view: self.tool3TargetLabel, enable: false)
            self.state(view: self.tool3SplitLabel, enable: false)
            self.state(view: self.tool3TitleLabel, enable: false)
            self.tool3SetTempButton.isEnabled = false
            // Disable tool4 info
            self.state(view: self.tool4ActualLabel, enable: false)
            self.state(view: self.tool4TargetLabel, enable: false)
            self.state(view: self.tool4SplitLabel, enable: false)
            self.state(view: self.tool4TitleLabel, enable: false)
            self.tool4TitleConstraint?.isActive = false
            self.tool4SetTempButton.isEnabled = false

            self.bedActualLabel.text = "            " // Use empty spaces to position Bed label in a good place
            self.bedTargetLabel.text = "        " // Use empty spaces to position Bed label in a good place
            self.bedSplitLabel.isHidden = true
            
            // Disable these buttons
            self.bedSetTempButton.isEnabled = false
            self.tool0SetTempButton.isEnabled = false
            
            // Force to recalculate rows height since cells may not be visible
            self.tableView.beginUpdates()
            self.tableView.endUpdates()
            self.checkTempLabelVisibility()
        }
    }
    
    fileprivate func state(view: UILabel, enable: Bool) {
        view.isEnabled = enable
        view.alpha = enable ? 1.0 : 0.6
    }
    
    /// Call from **main thread**. Alert if visibility of tool0ActualLabel has changed
    fileprivate func checkTempLabelVisibility() {
        let currentVisiblity = tempLabelVisible()
        if tool0ActualLabelIsVisibile != currentVisiblity {
            tool0ActualLabelIsVisibile = currentVisiblity
            // Alert listeners about change in visibility
            if let parentVC = parent?.parent as? SubpanelsViewController {
                parentVC.toolLabelVisibilityChanged()
            }
        }
    }

    /// Call from **main thread**. Returns true if actual temperature of tool 0
    /// is fully visible in the UI
    func tempLabelVisible() -> Bool {
        let rowOrigin = toolRow0.frame.origin
        let labelFrame = tool0ActualLabel.frame
        let labelOrigin = labelFrame.origin
        let thePosition: CGRect =  CGRect(x: rowOrigin.x + labelOrigin.x, y: rowOrigin.y + labelOrigin.y, width: labelFrame.width, height: labelFrame.height)

        return tableView.bounds.contains(thePosition)
    }
    
    fileprivate func themeLabels() {
        let theme = Theme.currentTheme()
        let textLabelColor = theme.labelColor()
        let textColor = theme.textColor()
        let tintColor = theme.tintColor()

        printedTextLabel.textColor = textLabelColor
        printTimeTextLabel.textColor = textLabelColor
        printTimeLeftTextLabel.textColor = textLabelColor
        printEstimatedCompletionTextLabel.textColor = textLabelColor
        printerStatusTextLabel.textColor = textLabelColor
        currentHeightTextLabel.textColor = textLabelColor
        layerTextLabel.textColor = textLabelColor
        tool0TitleLabel.textColor = textLabelColor
        tool0SplitLabel.textColor = textLabelColor
        bedTextLabel.textColor = textLabelColor
        bedSplitLabel.textColor = textLabelColor
        tool1TitleLabel.textColor = textLabelColor
        tool1SplitLabel.textColor = textLabelColor
        chamberTitleLabel.textColor = textLabelColor
        chamberSplitLabel.textColor = textLabelColor
        tool2TitleLabel.textColor = textLabelColor
        tool2SplitLabel.textColor = textLabelColor
        tool3TitleLabel.textColor = textLabelColor
        tool3SplitLabel.textColor = textLabelColor
        tool4TitleLabel.textColor = textLabelColor
        tool4SplitLabel.textColor = textLabelColor

        printerStatusLabel.textColor = textColor
        printingFileLabel.textColor = textColor
        progressLabel.textColor = textColor
        printTimeLabel.textColor = textColor
        printTimeLeftLabel.textColor = textColor
        printEstimatedCompletionLabel.textColor = textColor
        currentHeightLabel.textColor = textColor
        layerLabel.textColor = textColor
        tool0ActualLabel.textColor = textColor
        tool0TargetLabel.textColor = textColor
        tool1ActualLabel.textColor = textColor
        tool1TargetLabel.textColor = textColor
        chamberActualLabel.textColor = textColor
        chamberTargetLabel.textColor = textColor
        tool2ActualLabel.textColor = textColor
        tool2TargetLabel.textColor = textColor
        tool3ActualLabel.textColor = textColor
        tool3TargetLabel.textColor = textColor
        tool4ActualLabel.textColor = textColor
        tool4TargetLabel.textColor = textColor
        bedActualLabel.textColor = textColor
        bedTargetLabel.textColor = textColor
        
        printButton.tintColor = tintColor
        restartButton.tintColor = tintColor
        pauseButton.tintColor = tintColor
        cancelButton.tintColor = tintColor
        resumeButton.tintColor = tintColor
    }
    
    fileprivate func showAlert(_ title: String, message: String) {
        UIUtils.showAlert(presenter: self, title: title, message: message, done: nil)
    }
    
    fileprivate func showConfirm(message: String, yes: @escaping (UIAlertAction) -> Void, no: @escaping (UIAlertAction) -> Void) {
        UIUtils.showConfirm(presenter: self, message: message, yes: yes, no: no)
    }
}
