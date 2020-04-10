import UIKit

class SelectDefaultPrinterViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()

    var printers: [Printer]!
    var panelViewController: PanelViewController?
    
    var currentTheme: Theme.ThemeChoice!
    
    @IBOutlet weak var dashboardButton: UIButton!
    @IBOutlet weak var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Remember current theme so we know when to repaint
        currentTheme = Theme.currentTheme()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        printers = printerManager.getPrinters()

        ThemeUIUtils.applyTheme(table: tableView, staticCells: false)

        if currentTheme != Theme.currentTheme() {
            currentTheme = Theme.currentTheme()
            tableView.reloadData()
        }

        // Set background color of popover and its arrow based on current theme
        self.popoverPresentationController?.backgroundColor = currentTheme.backgroundColor()
        
        dashboardButton.setTitleColor(currentTheme.tintColor(), for: .normal) 
        view.backgroundColor = currentTheme.backgroundColor()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return printers.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "printerCell", for: indexPath)

        cell.textLabel?.text = printers[indexPath.row].name // + (printers[indexPath.row].defaultPrinter ? " (Active)" : "")
        cell.detailTextLabel?.text = printers[indexPath.row].hostname
        // Show a checkmark next to active printer
        cell.accessoryType = printers[indexPath.row].defaultPrinter ? .checkmark : .none

        // Theme color of labels
        let theme = Theme.currentTheme()
        cell.textLabel?.textColor = theme.textColor()
        cell.detailTextLabel?.textColor = theme.textColor()

        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        panelViewController?.changeDefaultPrinter(printer: printers[indexPath.row])
        dismiss(animated: true, completion: nil)
    }

    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        ThemeUIUtils.themeCell(cell: cell)
    }

    // MARK: - Button actions
    
    @IBAction func openPrintersDashboard(_ sender: Any) {
        dismiss(animated: true) {
            self.panelViewController?.performSegue(withIdentifier: "printers_dashboard", sender: nil)
        }
    }
}
