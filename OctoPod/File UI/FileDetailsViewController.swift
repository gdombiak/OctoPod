import UIKit

class FileDetailsViewController: ThemedStaticUITableViewController {
    
    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()

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
        estimatedPrintTimeLabel.text = UIUtils.secondsToEstimatedPrintTime(seconds: printFile?.estimatedPrintTime)
        uploadedDateLabel.text = UIUtils.dateToString(date: printFile?.date)
        printedDateLabel.text = UIUtils.dateToString(date: printFile?.lastPrintDate)
        
        printButton.isEnabled = printFile != nil && printFile!.canBePrinted() && !appConfiguration.appLocked()
        deleteButton.isEnabled = printFile != nil && printFile!.canBeDeleted() && !appConfiguration.appLocked()
        
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
