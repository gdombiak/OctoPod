import UIKit

class MoveViewController: UITableViewController {

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

    fileprivate func showAlert(_ title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: { (UIAlertAction) -> Void in
            // Nothing to do here
        }))
        self.present(alert, animated: true) { () -> Void in
            // Nothing to do here
        }
    }
}
