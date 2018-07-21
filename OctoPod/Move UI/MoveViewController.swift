import UIKit

// OctoPrint does not report current fan speed or extruder flow rate so we
// initially assume 100% and then just leave last value set by user. Display
// value will go back to 100% if app is terminated
class MoveViewController: UITableViewController, UIPopoverPresentationControllerDelegate {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if let printer = printerManager.getDefaultPrinter() {
            // Update window title to Camera name
            navigationItem.title = printer.name
            
            enableButtons(enable: true)
        } else {
            navigationItem.title = "Move"
            enableButtons(enable: false)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - XY Operations

    @IBAction func goBack(_ sender: Any) {
        if let selected = xyStepSegmentedControl.titleForSegment(at: xyStepSegmentedControl.selectedSegmentIndex) {
            let delta = (selected as NSString).floatValue * -1
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
            let delta = (selected as NSString).floatValue
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
            let delta = Float(selected)! * -1
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
            let delta = Float(selected)!
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
            let delta = Float(selected)!
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
            let delta = Float(selected)! * -1
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
    
    // MARK: - Table view operations
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 1
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "send_gcode", let controller = segue.destination as? SendGCodeViewController {
            controller.popoverPresentationController!.delegate = self
        }
    }
    
    // MARK: - Unwind operations
    
    @IBAction func backFromSendGCode(_ sender: UIStoryboardSegue) {
        if let controller = sender.source as? SendGCodeViewController, let text = controller.gCodeField.text {
            octoprintClient.sendCommand(gcode: text.uppercased()) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                if !requested {
                    // Handle error
                    var message = "Failed to send GCode command"
                    if response.statusCode == 409 {
                        message = "Printer not operational"
                    }
                    self.showAlert("Alert", message: message)
                }
            }
        }
    }
    
    // MARK: - UIPopoverPresentationControllerDelegate
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
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

    fileprivate func showAlert(_ title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: { (UIAlertAction) -> Void in
            // Nothing to do here
        }))
        // Present dialog on main thread to prevent crashes
        DispatchQueue.main.async {
            self.present(alert, animated: true) { () -> Void in
                // Nothing to do here
            }
        }
    }
}
