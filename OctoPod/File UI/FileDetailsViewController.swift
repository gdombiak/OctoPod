import UIKit

class FileDetailsViewController: UITableViewController {
    
    var printFile: PrintFile?

    @IBOutlet weak var fileNameLabel: UILabel!
    @IBOutlet weak var sizeLabel: UILabel!
    @IBOutlet weak var originLabel: UILabel!
    @IBOutlet weak var estimatedPrintTimeLabel: UILabel!
    @IBOutlet weak var uploadedDateLabel: UILabel!
    
    @IBOutlet weak var printButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Hide empty rows at the bottom of the table
        tableView.tableFooterView = UIView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        fileNameLabel.text = printFile?.display
        sizeLabel.text = printFile?.displaySize()
        originLabel.text = printFile?.displayOrigin()
        estimatedPrintTimeLabel.text = secondsToEstimatedPrintTime(seconds: printFile?.estimatedPrintTime)
        uploadedDateLabel.text = dateToString(date: printFile?.date)
        
        printButton.isEnabled = printFile != nil && printFile!.canBePrinted()
        deleteButton.isEnabled = printFile != nil && printFile!.canBeDeleted()
    }
    
    @IBAction func printClicked(_ sender: Any) {
        performSegue(withIdentifier: "backFromPrint", sender: self)
    }
    
    @IBAction func deleteClicked(_ sender: Any) {        
        performSegue(withIdentifier: "backFromDelete", sender: self)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    // MARK: - Private functions
    
    // Converts number of seconds into a string that represents aproximate time (e.g. About 23h 10m)
    fileprivate func secondsToEstimatedPrintTime(seconds: Double?) -> String {
        if seconds == nil || seconds == 0 {
            return ""
        }
        let duration = TimeInterval(Int(seconds!))
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .brief
        formatter.includesApproximationPhrase = true
        formatter.allowedUnits = [ .day, .hour, .minute ]
        return formatter.string(from: duration)!
    }
    
    fileprivate func dateToString(date: Date?) -> String {
        if let dateToConvert = date {
            return DateFormatter.localizedString(from: dateToConvert, dateStyle: DateFormatter.Style.medium, timeStyle: DateFormatter.Style.medium)
        }
        return ""
    }    
}
