import UIKit

class JobInfoViewController: UITableViewController {
    
    enum jobOperation {
        case cancel
        case pause
        case resume
    }

    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    
    var printerPrinting: Bool?
    var requestedJobOperation: jobOperation?

    @IBOutlet weak var fileLabel: UILabel!
    @IBOutlet weak var sizeLabel: UILabel!
    @IBOutlet weak var originLabel: UILabel!
    
    @IBOutlet weak var pauseOrResumeButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.octoprintClient.printerState { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
            // TODO Handle connection errors
            if let json = result as? NSDictionary {
                let event = CurrentStateEvent()
                if let state = json["state"] as? NSDictionary {
                    event.parseState(state: state)

                    var buttonTitle: String?
                    if event.printing == true {
                        buttonTitle = "Pause"
                        self.printerPrinting = true
                    } else if event.paused == true {
                        buttonTitle = "Resume"
                        self.printerPrinting = false
                    }

                    DispatchQueue.main.async {
                        if let newTitle = buttonTitle {
                            self.pauseOrResumeButton.setTitle(newTitle, for: UIControlState.normal)
                        } else {
                            self.pauseOrResumeButton.isEnabled = false
                        }
                    }
                }
            } else {
                // Might not be even connected
                DispatchQueue.main.async {
                    self.pauseOrResumeButton.isEnabled = false
                    self.cancelButton.isEnabled = false
                }
            }
        }

        self.octoprintClient.currentJobInfo { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
            // TODO Handle connection errors
            if let json = result as? NSDictionary {
                if let job = json["job"] as? NSDictionary {
                    if let file = job["file"] as? NSDictionary {
                        let printFile = PrintFile()
                        printFile.parse(json: file)

                        DispatchQueue.main.async {
                            self.fileLabel.text = printFile.name
                            self.originLabel.text = printFile.displayOrigin()
                            self.sizeLabel.text = printFile.displaySize()
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
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 1
    }
    
    @IBAction func cancelJob(_ sender: Any) {
        self.octoprintClient.cancelCurrentJob { (requested: Bool, error: Error?, response: HTTPURLResponse) in
            if requested {
                self.dismiss(animated: true, completion: nil)
            } else {
                NSLog("Error requesting to cancel current job: \(String(describing: error?.localizedDescription)). Http response: \(response.statusCode)")
                self.requestedJobOperation = .cancel
                self.performSegue(withIdentifier: "backFromFailedJobRequest", sender: self)
            }
        }
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
}
