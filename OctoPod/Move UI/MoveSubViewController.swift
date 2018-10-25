import UIKit

// OctoPrint does not report current fan speed, extruder flow rate or feed rate so we
// initially assume 100% and then just leave last value set by user. Display
// value will go back to 100% if app is terminated
class MoveSubViewController: ThemedStaticUITableViewController, PrinterProfilesDelegate, AppConfigurationDelegate, WatchSessionManagerDelegate {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()
    let watchSessionManager: WatchSessionManager = { return (UIApplication.shared.delegate as! AppDelegate).watchSessionManager }()

    @IBOutlet weak var flowRateTextLabel: UILabel!
    @IBOutlet weak var fanTextLabel: UILabel!
    @IBOutlet weak var disableMotorLabel: UILabel!
    @IBOutlet weak var feedRateTextLabel: UILabel!
    
    @IBOutlet weak var xyStepSegmentedControl: UISegmentedControl!
    @IBOutlet weak var zStepSegmentedControl: UISegmentedControl!
    @IBOutlet weak var eStepSegmentedControl: UISegmentedControl!
    
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var frontButton: UIButton!
    @IBOutlet weak var leftButton: UIButton!
    @IBOutlet weak var rightButton: UIButton!
    
    @IBOutlet weak var upButton: UIButton!
    @IBOutlet weak var downButton: UIButton!
    
    @IBOutlet weak var goHomeButton: UIButton!
    
    @IBOutlet weak var retractButton: UIButton!
    @IBOutlet weak var extrudeButton: UIButton!
    @IBOutlet weak var flowRateLabel: UILabel!
    @IBOutlet weak var flowRateSlider: UISlider!
    
    @IBOutlet weak var fanSpeedLabel: UILabel!
    @IBOutlet weak var feedRateLabel: UILabel!
    @IBOutlet weak var fanSpeedSlider: UISlider!
    @IBOutlet weak var xMotorButton: UIButton!
    @IBOutlet weak var yMotorButton: UIButton!
    @IBOutlet weak var zMotorButton: UIButton!
    @IBOutlet weak var eMotorButton: UIButton!
    @IBOutlet weak var feedRateSlider: UISlider!
    
    // Track if axis are inverted
    var invertedX = false
    var invertedY = false
    var invertedZ = false

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Listen to PrintProfile events
        octoprintClient.printerProfilesDelegates.append(self)
        // Listen to changes when app is locked or unlocked
        appConfiguration.delegates.append(self)
        // Listen to changes coming from Apple Watch
        watchSessionManager.delegates.append(self)

        refreshNewSelectedPrinter()

        themeLabels()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Stop listening to PrintProfile events
        octoprintClient.remove(printerProfilesDelegate: self)
        // Stop listening to changes when app is locked or unlocked
        appConfiguration.remove(appConfigurationDelegate: self)
        // Stop listening to changes coming from Apple Watch
        watchSessionManager.remove(watchSessionManagerDelegate: self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - XY Operations

    @IBAction func goBack(_ sender: Any) {
        if let selected = xyStepSegmentedControl.titleForSegment(at: xyStepSegmentedControl.selectedSegmentIndex) {
            let delta = (selected as NSString).floatValue * (invertedY ? 1 : -1)
            octoprintClient.move(y: delta) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                if !requested {
                    // Handle error
                    NSLog("Error moving Y axis. HTTP status code \(response.statusCode)")
                    self.showAlert(message: NSLocalizedString("Failed to request moving back", comment: ""))
                }
            }
        }
    }
    
    @IBAction func goFront(_ sender: Any) {
        if let selected = xyStepSegmentedControl.titleForSegment(at: xyStepSegmentedControl.selectedSegmentIndex) {
            let delta = (selected as NSString).floatValue * (invertedY ? -1 : 1)
            octoprintClient.move(y: delta) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                if !requested {
                    // Handle error
                    NSLog("Error moving Y axis. HTTP status code \(response.statusCode)")
                    self.showAlert(message: NSLocalizedString("Failed to request moving front", comment: ""))
                }
            }
        }
    }
    
    @IBAction func goLeft(_ sender: Any) {
        if let selected = xyStepSegmentedControl.titleForSegment(at: xyStepSegmentedControl.selectedSegmentIndex) {
            let delta = Float(selected)! * (invertedX ? 1 : -1)
            octoprintClient.move(x: delta) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                if !requested {
                    // Handle error
                    NSLog("Error moving X axis. HTTP status code \(response.statusCode)")
                    self.showAlert(message: NSLocalizedString("Failed to request moving left", comment: ""))
                }
            }
        }
    }
    
    @IBAction func goRight(_ sender: Any) {
        if let selected = xyStepSegmentedControl.titleForSegment(at: xyStepSegmentedControl.selectedSegmentIndex) {
            let delta = Float(selected)! * (invertedX ? -1 : 1)
            octoprintClient.move(x: delta) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                if !requested {
                    // Handle error
                    NSLog("Error moving X axis. HTTP status code \(response.statusCode)")
                    self.showAlert(message: NSLocalizedString("Failed to request moving right", comment: ""))
                }
            }
        }
    }
    
    // MARK: - Z Operations

    @IBAction func goUp(_ sender: Any) {
        if let selected = zStepSegmentedControl.titleForSegment(at: zStepSegmentedControl.selectedSegmentIndex) {
            let delta = Float(selected)! * (invertedZ ? -1 : 1)
            octoprintClient.move(z: delta) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                if !requested {
                    // Handle error
                    NSLog("Error moving Z axis. HTTP status code \(response.statusCode)")
                    self.showAlert(message: NSLocalizedString("Failed to request moving up", comment: ""))
                }
            }
        }
    }
    
    @IBAction func goDown(_ sender: Any) {
        if let selected = zStepSegmentedControl.titleForSegment(at: zStepSegmentedControl.selectedSegmentIndex) {
            let delta = Float(selected)! * (invertedZ ? 1 : -1)
            octoprintClient.move(z: delta) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                if !requested {
                    // Handle error
                    NSLog("Error moving Z axis. HTTP status code \(response.statusCode)")
                    self.showAlert(message: NSLocalizedString("Failed to request moving down", comment: ""))
                }
            }
        }
    }
    
    @IBAction func goHome(_ sender: Any) {
        octoprintClient.home { (requested: Bool, error: Error?, response: HTTPURLResponse) in
            if !requested {
                // Handle error
                NSLog("Error going home. HTTP status code \(response.statusCode)")
                self.showAlert(message: NSLocalizedString("Failed to request to go home", comment: ""))
            }
        }
    }
    
    // MARK: - E Operations

    @IBAction func retract(_ sender: Any) {
        if let selected = eStepSegmentedControl.titleForSegment(at: eStepSegmentedControl.selectedSegmentIndex) {
            let delta = Int(selected)! * -1
            octoprintClient.extrude(toolNumber: 0, delta: delta, callback: { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                if !requested {
                    // Handle error
                    NSLog("Error moving E axis. HTTP status code \(response.statusCode)")
                    self.showAlert(message: NSLocalizedString("Failed to request to retract", comment: ""))
                }
            })
        }
    }
    
    @IBAction func extrude(_ sender: Any) {
        if let selected = eStepSegmentedControl.titleForSegment(at: eStepSegmentedControl.selectedSegmentIndex) {
            let delta = Int(selected)!
            octoprintClient.extrude(toolNumber: 0, delta: delta, callback: { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                if !requested {
                    // Handle error
                    NSLog("Error moving E axis. HTTP status code \(response.statusCode)")
                    self.showAlert(message: NSLocalizedString("Failed to request to extrude", comment: ""))
                }
            })
        }
    }
    
    @IBAction func flowRateChanging(_ sender: UISlider) {
        // Update label with value of slider
        flowRateLabel.text = "\(String(format: "%.0f", sender.value))%"
    }
    
    @IBAction func flowRateChanged(_ sender: UISlider) {
        // Ask OctoPrint to set new flow rate for extruder
        let newFlowRate = Int(String(format: "%.0f", sender.value))!
        octoprintClient.toolFlowRate(toolNumber: 0, newFlowRate: newFlowRate, callback: { (requested: Bool, error: Error?, response: HTTPURLResponse) in
            if !requested {
                // Handle error
                NSLog("Error setting new flow rate. HTTP status code \(response.statusCode)")
                self.showAlert(message: NSLocalizedString("Failed to set new flow rate", comment: ""))
            }
        })
    }
    
    // MARK: - Fan and Motors Operations
    
    @IBAction func fanSpeedChanging(_ sender: UISlider) {
        // Update label with value of slider
        fanSpeedLabel.text = "\(String(format: "%.0f", sender.value))%"
    }
    
    @IBAction func fanSpeedChanged(_ sender: UISlider) {
        // Ask OctoPrint to set new fan speed
        let newSpeed = Int(String(format: "%.0f", sender.value))!
        octoprintClient.fanSpeed(speed: newSpeed, callback: { (requested: Bool, error: Error?, response: HTTPURLResponse) in
            if !requested {
                // Handle error
                NSLog("Error setting new fan speed. HTTP status code \(response.statusCode)")
                self.showAlert(message: NSLocalizedString("Failed to set new fan speed", comment: ""))
            }
        })
    }
    
    @IBAction func disableMotorX(_ sender: Any) {
        disableMotor(axis: .X)
    }
    
    @IBAction func disableMotorY(_ sender: Any) {
        disableMotor(axis: .Y)
    }
    
    @IBAction func disableMotorZ(_ sender: Any) {
        disableMotor(axis: .Z)
    }
    
    @IBAction func disableMotorE(_ sender: Any) {
        disableMotor(axis: .E)
    }
    
    @IBAction func feedRateChanging(_ sender: UISlider) {
        // Update label with value of slider
        feedRateLabel.text = "\(String(format: "%.0f", sender.value))%"
    }
    
    @IBAction func feedRateChanged(_ sender: UISlider) {
        // Ask OctoPrint to set new fan speed
        let newRate = Int(String(format: "%.0f", sender.value))!
        octoprintClient.feedRate(factor: newRate, callback: { (requested: Bool, error: Error?, response: HTTPURLResponse) in
            if !requested {
                // Handle error
                NSLog("Error setting new feed rate. HTTP status code \(response.statusCode)")
                self.showAlert(message: NSLocalizedString("Failed to set new feed rate", comment: ""))
            }
        })
    }
    
    // MARK: - Table view operations
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 1
    }
    
    // MARK: - PrinterProfilesDelegate
    
    func axisDirectionChanged(axis: axis, inverted: Bool) {
        switch axis {
        case .X:
            invertedX = inverted
        case .Y:
            invertedY = inverted
        case .Z:
            invertedZ = inverted
        case .E:
            // Do nothing
            break
        }
    }
    
    // MARK: - AppConfigurationDelegate
    
    func appLockChanged(locked: Bool) {
        DispatchQueue.main.async {
            self.enableButtons(enable: !locked) // Enable/disable buttons based on app locked status
        }
    }

    // MARK: - WatchSessionManagerDelegate
    
    // Notification that a new default printer has been selected from the Apple Watch app
    func defaultPrinterChanged() {
        DispatchQueue.main.async {
            self.refreshNewSelectedPrinter()
        }
    }
    
    // MARK: - Private fuctions
    
    fileprivate func enableButtons(enable: Bool) {
        backButton.isEnabled = enable
        frontButton.isEnabled = enable
        leftButton.isEnabled = enable
        rightButton.isEnabled = enable
        
        upButton.isEnabled = enable
        downButton.isEnabled = enable
        
        goHomeButton.isEnabled = enable
        
        retractButton.isEnabled = enable
        extrudeButton.isEnabled = enable
        flowRateSlider.isEnabled = enable
        
        fanSpeedSlider.isEnabled = enable
        xMotorButton.isEnabled = enable
        yMotorButton.isEnabled = enable
        zMotorButton.isEnabled = enable
        eMotorButton.isEnabled = enable
        feedRateSlider.isEnabled = enable
    }
    
    fileprivate func disableMotor(axis: axis) {
        octoprintClient.disableMotor(axis: axis, callback: { (requested: Bool, error: Error?, response: HTTPURLResponse) in
            if !requested {
                // Handle error
                NSLog("Error disabling \(axis) motor. HTTP status code \(response.statusCode)")
                self.showAlert(message: String(format: NSLocalizedString("Failed to disable motor", comment: ""), "\(axis)"))
            }
        })
    }
    
    fileprivate func refreshNewSelectedPrinter() {
        if let printer = printerManager.getDefaultPrinter() {
            enableButtons(enable: !appConfiguration.appLocked()) // Enable/disable buttons based on app locked status
            // Remember if axis are inverted
            invertedX = printer.invertX
            invertedY = printer.invertY
            invertedZ = printer.invertZ
            
        } else {
            enableButtons(enable: false)
        }
    }

    fileprivate func themeLabels() {
        let theme = Theme.currentTheme()
        let textLabelColor = theme.labelColor()
        let textColor = theme.textColor()
        
        flowRateTextLabel.textColor = textLabelColor
        fanTextLabel.textColor = textLabelColor
        disableMotorLabel.textColor = textLabelColor
        feedRateTextLabel.textColor = textLabelColor
        
        flowRateLabel.textColor = textColor
        fanSpeedLabel.textColor = textColor
        feedRateLabel.textColor = textColor
    }

    fileprivate func showAlert(message: String) {
        UIUtils.showAlert(presenter: self, title: NSLocalizedString("Warning", comment: ""), message: message, done: nil)
    }
}
