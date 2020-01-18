import UIKit

class PingPongHistoryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var varianceStatsView: UIView!
    
    @IBOutlet weak var maxTextLabel: UILabel!
    @IBOutlet weak var maxLabel: UILabel!
    @IBOutlet weak var averageTextLabel: UILabel!
    @IBOutlet weak var averageLabel: UILabel!
    @IBOutlet weak var minTextLabel: UILabel!
    @IBOutlet weak var minLabel: UILabel!
    
    var history: Array<Dictionary<String,Any>>?

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        ThemeUIUtils.applyTheme(table: tableView, staticCells: false)
        applyTheme()
        // To force repaint of theme when coming back straight from a new Appearance
        self.tableView.reloadData()
        if let history = history, let stats = Palette2ViewController.pingPongVarianceStats(history: history, reversed: true) {
            maxLabel.text = stats.max
            averageLabel.text = stats.average
            minLabel.text = stats.min
        } else {
            maxLabel.text = "0.0%"
            averageLabel.text = "0.0%"
            minLabel.text = "0.0%"
        }
    }

    // MARK: - Table view data source

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return history?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let theme = Theme.currentTheme()
        let textColor = theme.textColor()

        let cell = tableView.dequeueReusableCell(withIdentifier: "history_cell", for: indexPath)

        // Configure the cell...
        if let history = history, let messages = Palette2ViewController.pingPongMessage(history: history, index: indexPath.row, reversed: true) {
            
            if let numberLabel = cell.viewWithTag(100) as? UILabel {
                numberLabel.text = "# " + messages.number
                numberLabel.textColor = textColor
            }

            if let prctLabel = cell.viewWithTag(101) as? UILabel {
                prctLabel.text = messages.percent
                prctLabel.textColor = textColor
            }

            if let varianceLabel = cell.viewWithTag(102) as? UILabel {
                varianceLabel.text = messages.variance
                varianceLabel.textColor = textColor
            }
        }

        return cell
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        ThemeUIUtils.themeCell(cell: cell)
    }
    
    // MARK: - Theme functions

    fileprivate func applyTheme() {
        let theme = Theme.currentTheme()
        let textLabelColor = theme.labelColor()
        let textColor = theme.textColor()
        
        varianceStatsView.backgroundColor = theme.backgroundColor()
        
        maxTextLabel.textColor = textLabelColor
        averageTextLabel.textColor = textLabelColor
        minTextLabel.textColor = textLabelColor

        maxLabel.textColor = textColor
        averageLabel.textColor = textColor
        minLabel.textColor = textColor

    }
}
