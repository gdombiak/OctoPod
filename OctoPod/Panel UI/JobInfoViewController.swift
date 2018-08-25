import UIKit

class JobInfoViewController: UITableViewController {
    
    enum jobOperation {
        case cancel
        case pause
        case resume
        case restart
        case reprint
    }

    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    
    var printerPrinting: Bool?
    var requestedJobOperation: jobOperation?
    
    var event: CurrentStateEvent?
    var printFile: PrintFile?

    @IBOutlet weak var fileLabel: UILabel!
    @IBOutlet weak var sizeLabel: UILabel!
    @IBOutlet weak var originLabel: UILabel!
    
    @IBOutlet weak var restartButton: UIButton!
    @IBOutlet weak var pauseOrResumeButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        event = nil
        printFile = nil
        
        self.octoprintClient.printerState { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
            // TODO Handle connection errors
            if let json = result as? NSDictionary {
                self.event = CurrentStateEvent()
                if let state = json["state"] as? NSDictionary {
                    self.event!.parseState(state: state)

                    var buttonTitle: String?
                    if self.event!.printing == true {
                        buttonTitle = "Pause Job"
                        self.printerPrinting = true
                    } else if self.event!.paused == true {
                        buttonTitle = "Resume Job"
                        self.printerPrinting = false
                    }

                    DispatchQueue.main.async {
                        if let newTitle = buttonTitle {
                            self.pauseOrResumeButton.setTitle(newTitle, for: UIControlState.normal)
                            self.pauseOrResumeButton.isEnabled = true
                        } else {
                            self.pauseOrResumeButton.isEnabled = false
                        }
                        self.configureRestartReprintButton()
                    }
                }
            } else {
                // Might not be even connected
                DispatchQueue.main.async {
                    self.pauseOrResumeButton.isEnabled = false
                    self.cancelButton.isEnabled = false
                    self.restartButton.isEnabled = false
                }
            }
        }

        self.octoprintClient.currentJobInfo { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
            // TODO Handle connection errors
            if let json = result as? NSDictionary {
                if let job = json["job"] as? NSDictionary {
                    if let file = job["file"] as? NSDictionary {
                        self.printFile = PrintFile()
                        self.printFile!.parse(json: file)
                        if self.printFile!.path == nil {
                            // Forget about an empty file
                            self.printFile = nil
                        }

                        DispatchQueue.main.async {
                            self.fileLabel.text = self.printFile?.name
                            self.originLabel.text = self.printFile?.displayOrigin()
                            self.sizeLabel.text = self.printFile?.displaySize()
                            self.configureRestartReprintButton()
                        }
                    }
                }
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Table view operations

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 1
    }
    
    // MARK: - Button actions
    
    @IBAction func cancelJob(_ sender: Any) {
        // Prompt for confirmation that we want to cancel the print job
        showConfirm(message: "Do you want to cancel job?", yes: { (UIAlertAction) in
            self.octoprintClient.cancelCurrentJob { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                if requested {
                    self.dismiss(animated: true, completion: nil)
                } else {
                    NSLog("Error requesting to cancel current job: \(String(describing: error?.localizedDescription)). Http response: \(response.statusCode)")
                    self.requestedJobOperation = .cancel
                    self.performSegue(withIdentifier: "backFromFailedJobRequest", sender: self)
                }
            }
        }, no: { (UIAlertAction) -> Void in
            // Do nothing
        })
        
    }
    
    @IBAction func pauseOrResumeJob(_ sender: Any) {
        if let printing = printerPrinting {
            if printing {
                self.octoprintClient.pauseCurrentJob { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                    if requested {
                        self.dismiss(animated: true, completion: nil)
                    } else {
                        NSLog("Error requesting to pause current job: \(String(describing: error?.localizedDescription)). Http response: \(response.statusCode)")
                        self.requestedJobOperation = .pause
                        self.performSegue(withIdentifier: "backFromFailedJobRequest", sender: self)
                    }
                }
            } else {
                self.octoprintClient.resumeCurrentJob { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                    if requested {
                        self.dismiss(animated: true, completion: nil)
                    } else {
                        NSLog("Error requesting to resume current job: \(String(describing: error?.localizedDescription)). Http response: \(response.statusCode)")
                        self.requestedJobOperation = .resume
                        self.performSegue(withIdentifier: "backFromFailedJobRequest", sender: self)
                    }
                }
            }
        }
    }
    
    @IBAction func restartOrReprintJob(_ sender: Any) {
        if let lastEvent = event, let lastFile = printFile {
            if lastEvent.operational == true && lastEvent.printing != true && lastEvent.paused != true {
                // Print file if there is a file and printer is operationsl
                self.octoprintClient.printFile(origin: lastFile.origin!, path: lastFile.path!) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                    if requested {
                        self.dismiss(animated: true, completion: nil)
                    } else {
                        NSLog("Error requesting to reprint file: \(String(describing: error?.localizedDescription)). Http response: \(response.statusCode)")
                        self.requestedJobOperation = .reprint
                        self.performSegue(withIdentifier: "backFromFailedJobRequest", sender: self)
                    }
                }
            }
            else {
                // Restart when print job is paused
                self.octoprintClient.restartCurrentJob { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                    if requested {
                        self.dismiss(animated: true, completion: nil)
                    } else {
                        NSLog("Error requesting to restart current job: \(String(describing: error?.localizedDescription)). Http response: \(response.statusCode)")
                        self.requestedJobOperation = .restart
                        self.performSegue(withIdentifier: "backFromFailedJobRequest", sender: self)
                    }
                }
            }
        }
    }
    
    // MARK: - Private functions
    
    fileprivate func configureRestartReprintButton() {
        if let lastEvent = event, let _ = printFile {
            if lastEvent.operational == true && lastEvent.printing != true && lastEvent.paused != true {
                // Allow to print file if there is a file and printer is operationsl
                self.restartButton.setTitle("Print File", for: .normal)
                self.restartButton.isEnabled = true
                self.cancelButton.isEnabled = false
                return
            } else {
                // Only enable option to restart when print job is paused
                self.restartButton.setTitle("Restart Job", for: .normal)
                self.restartButton.isEnabled = lastEvent.paused == true
                self.cancelButton.isEnabled = true
            }
        } else {
            self.restartButton.isEnabled = false
        }
    }
    
    fileprivate func showConfirm(message: String, yes: @escaping (UIAlertAction) -> Void, no: @escaping (UIAlertAction) -> Void) {
        let alert = UIAlertController(title: "Confirm", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: yes))
        // Use default style and not cancel style for NO so it appears on the right
        alert.addAction(UIAlertAction(title: "No", style: .default, handler: no))
        self.present(alert, animated: true) { () -> Void in
            // Nothing to do here
        }
    }
}
