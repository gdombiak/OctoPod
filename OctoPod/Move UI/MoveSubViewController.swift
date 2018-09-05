import UIKit

// OctoPrint does not report current fan speed, extruder flow rate or feed rate so we
// initially assume 100% and then just leave last value set by user. Display
// value will go back to 100% if app is terminated
class MoveSubViewController: ThemedStaticUITableViewController, PrinterProfilesDelegate {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    
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
    
    @IBOutlet weak var retractButton: UIButton!
    @IBOutlet weak var extrudeButton: UIButton!
    @IBOutlet weak var flowRateLabel: UILabel!
    
    @IBOutlet weak var fanSpeedLabel: UILabel!
    @IBOutlet weak var feedRateLabel: UILabel!
    
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

        if let printer = printerManager.getDefaultPrinter() {
            enableButtons(enable: true)
            // Remember if axis are inverted
            invertedX = printer.invertX
            invertedY = printer.invertY
            invertedZ = printer.invertZ

        } else {
            enableButtons(enable: false)
        }
        themeLabels()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Stop listening to PrintProfile events
        octoprintClient.remove(printerProfilesDelegate: self)
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
                    self.showAlert("Alert", message: "Failed to request moving back")
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
                    self.showAlert("Alert", message: "Failed to request moving front")
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
                    self.showAlert("Alert", message: "Failed to request moving left")
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
                    self.showAlert("Alert", message: "Failed to request moving right")
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
                    self.showAlert("Alert", message: "Failed to request moving up")
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
                    self.showAlert("Alert", message: "Failed to request moving down")
                }
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
                    self.showAlert("Alert", message: "Failed to request to retract")
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
                    self.showAlert("Alert", message: "Failed to request to extrude")
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
                self.showAlert("Alert", message: "Failed to set new flow rate")
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
                self.showAlert("Alert", message: "Failed to set new fan speed")
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
                self.showAlert("Alert", message: "Failed to set new feed rate")
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
    
    func axisDirectionChanged(axis: OctoPrintClient.axis, inverted: Bool) {
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
    
    // MARK: - Private fuctions
    
    fileprivate func enableButtons(enable: Bool) {
        backButton.isEnabled = enable
        frontButton.isEnabled = enable
        leftButton.isEnabled = enable
        rightButton.isEnabled = enable
        
        upButton.isEnabled = enable
        downButton.isEnabled = enable
        
        retractButton.isEnabled = enable
        extrudeButton.isEnabled = enable
    }
    
    fileprivate func disableMotor(axis: OctoPrintClient.axis) {
        octoprintClient.disableMotor(axis: axis, callback: { (requested: Bool, error: Error?, response: HTTPURLResponse) in
            if !requested {
                // Handle error
                NSLog("Error disabling \(axis) motor. HTTP status code \(response.statusCode)")
                self.showAlert("Alert", message: "Failed to disable \(axis) motor")
            }
        })
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

    fileprivate func showAlert(_ title: String, message: String) {
        UIUtils.showAlert(presenter: self, title: title, message: message, done: nil)
    }
}
