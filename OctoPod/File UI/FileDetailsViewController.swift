import UIKit

class FileDetailsViewController: ThemedStaticUITableViewController {
    
    var printFile: PrintFile?

    @IBOutlet weak var fileTextLabel: UILabel!
    @IBOutlet weak var sizeTextLabel: UILabel!
    @IBOutlet weak var originTextLabel: UILabel!
    @IBOutlet weak var printTimeTextLabel: UILabel!
    @IBOutlet weak var uploadedTextLabel: UILabel!
    @IBOutlet weak var printedTextLabel: UILabel!
    
    @IBOutlet weak var fileNameLabel: UILabel!
    @IBOutlet weak var sizeLabel: UILabel!
    @IBOutlet weak var originLabel: UILabel!
    @IBOutlet weak var estimatedPrintTimeLabel: UILabel!
    @IBOutlet weak var uploadedDateLabel: UILabel!
    @IBOutlet weak var printedDateLabel: UILabel!
    
    @IBOutlet weak var printButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Hide empty rows at the bottom of the table
        tableView.tableFooterView = UIView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fileNameLabel.text = printFile?.display
        sizeLabel.text = printFile?.displaySize()
        originLabel.text = printFile?.displayOrigin()
        estimatedPrintTimeLabel.text = secondsToEstimatedPrintTime(seconds: printFile?.estimatedPrintTime)
        uploadedDateLabel.text = dateToString(date: printFile?.date)
        printedDateLabel.text = dateToString(date: printFile?.lastPrintDate)
        
        printButton.isEnabled = printFile != nil && printFile!.canBePrinted()
        deleteButton.isEnabled = printFile != nil && printFile!.canBeDeleted()
        
        themeLabels()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Button operations

    @IBAction func printClicked(_ sender: Any) {
        performSegue(withIdentifier: "backFromPrint", sender: self)
    }
    
    @IBAction func deleteClicked(_ sender: Any) {        
        performSegue(withIdentifier: "backFromDelete", sender: self)
    }
    
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

    fileprivate func themeLabels() {
        let theme = Theme.currentTheme()
        let textLabelColor = theme.labelColor()
        let textColor = theme.textColor()
        
        fileTextLabel.textColor = textLabelColor
        sizeTextLabel.textColor = textLabelColor
        originTextLabel.textColor = textLabelColor
        printTimeTextLabel.textColor = textLabelColor
        uploadedTextLabel.textColor = textLabelColor
        printedTextLabel.textColor = textLabelColor

        fileNameLabel.textColor = textColor
        sizeLabel.textColor = textColor
        originLabel.textColor = textColor
        estimatedPrintTimeLabel.textColor = textColor
        uploadedDateLabel.textColor = textColor
        printedDateLabel.textColor = textColor
    }
}
