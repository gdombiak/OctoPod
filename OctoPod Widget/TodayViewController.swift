import UIKit
import NotificationCenter

class TodayViewController: UIViewController, NCWidgetProviding {
        
    var items: [JobInfo] = []
    
    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view from its nib.
        
        // Indicate that widget will use expanded mode so we can show any number of printers
        // and not be limited to 110 height limit. Show more/less will be available
        self.extensionContext?.widgetLargestAvailableDisplayMode = .expanded
    }
    
    func widgetActiveDisplayModeDidChange(_ activeDisplayMode: NCWidgetDisplayMode, withMaximumSize maxSize: CGSize) {
        if activeDisplayMode == .expanded {
            preferredContentSize = CGSize(width: 0.0, height: 300.0)
        } else {
            preferredContentSize = maxSize
        }
    }
        
    func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        // Perform any setup necessary in order to update the view.
        
        items = []
        let printers = printerManager.getPrinters()

        let queue = DispatchQueue(label: "org.octopod.widget.table.queue.id")
        var counter = printers.count

        for printer in printers {

            let restClient = getRESTClient(hostname: printer.hostname, apiKey: printer.apiKey, username: printer.username, password: printer.password)
            restClient.currentJobInfo { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
                if let result = result as? Dictionary<String, Any> {
                    var printerState: String
                    var printTimeLeft: Int?
                    var progressPrintTime: Int?
                    var progressCompletion: Double?
                    if let state = result["state"] as? String {
                        printerState = state.starts(with: "Offline (Error:") ? "Offline" : state
                    } else {
                        printerState = NSLocalizedString("Unknown", comment: "Priner state is Unknown")
                    }
                    if let progress = result["progress"] as? Dictionary<String, Any> {
                        printTimeLeft = progress["printTimeLeft"] as? Int
                        progressPrintTime = progress["progressPrintTime"] as? Int
                        progressCompletion = progress["completion"] as? Double
                    }
                    let jobInfo = JobInfo(printerName: printer.name, state: printerState, progressCompletion: progressCompletion, printTimeLeft: printTimeLeft, progressPrintTime: progressPrintTime)
                    queue.sync {
                        self.items.append(jobInfo)
                        counter = counter - 1
                    }
                } else {
                    NSLog("No JSON was returned for printer: \(printer.name). Error: \(String(describing: error?.localizedDescription))")
                    queue.sync {
                        counter = counter - 1
                    }
                }
                if counter == 0 {
                    DispatchQueue.main.async {
                        self.tableView.reloadData()
                    }
                }
            }

            
        }
        
        
        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData
        
        completionHandler(NCUpdateResult.newData)
    }
    

    // MARK: - Private functions
    
    fileprivate func getRESTClient(hostname: String, apiKey: String, username: String?, password: String?) -> OctoPrintRESTClient {
        let restClient = OctoPrintRESTClient()
        restClient.connectToServer(serverURL: hostname, apiKey: apiKey, username: username, password: password)
        restClient.timeoutIntervalForRequest = 3
        restClient.timeoutIntervalForResource = 5
        return restClient
    }
    
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

    // MARK: - Lazy variables
    
    lazy var persistentContainer: SharedPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = SharedPersistentContainer(name: "OctoPod")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    lazy var printerManager: PrinterManager = {
        let context = persistentContainer.viewContext
        var printerManager = PrinterManager()
        printerManager.managedObjectContext = context
        return printerManager
    }()
}

// MARK: - Table operations extensions

extension TodayViewController : UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "printer_status_cell", for: indexPath)
        if let nameLabel = cell.viewWithTag(100) as? UILabel {
            nameLabel.text = items[indexPath.row].printerName
        }
        if let stateLabel = cell.viewWithTag(101) as? UILabel {
            stateLabel.text = items[indexPath.row].state
        }
        if let progressLabel = cell.viewWithTag(200) as? UILabel {
            if let progress = items[indexPath.row].progressCompletion {
                let progressText = String(format: "%.1f", progress)
                progressLabel.text = "\(progressText)%"
            } else {
                progressLabel.text = ""
            }
        }
        if let timeLeftLabel = cell.viewWithTag(201) as? UILabel {
            if let seconds = items[indexPath.row].printTimeLeft {
                timeLeftLabel.text = secondsToTimeLeft(seconds: seconds)
            } else if items[indexPath.row].progressPrintTime != nil {
                timeLeftLabel.text = NSLocalizedString("Still stabilizing", comment: "Print time is being calculated")
            } else {
                timeLeftLabel.text = ""
            }
        }

        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Open OctoPod app and display selected printer
        if let printerName = items[indexPath.row].printerName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
            let url = URL(string: "octopod://\(printerName)")!
            self.extensionContext?.open(url, completionHandler: { (success) in
                if (!success) {
                    NSLog("Error: Failed to open app from Today Extension")
                }
            })
        }
    }
}

struct JobInfo {
    var printerName: String
    var state: String
    var progressCompletion: Double?
    var printTimeLeft: Int?
    var progressPrintTime: Int?
}
