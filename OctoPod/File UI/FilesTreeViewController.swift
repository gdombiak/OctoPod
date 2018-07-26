import UIKit

class FilesTreeViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    private var currentTheme: Theme.ThemeChoice!

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var sortByTextLabel: UILabel!
    @IBOutlet weak var sortByControl: UISegmentedControl!
    @IBOutlet weak var refreshSDButton: UIButton!
    var refreshControl: UIRefreshControl?

    var files: Array<PrintFile> = Array()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Remember current theme so we know when to repaint
        currentTheme = Theme.currentTheme()

        // Create, configure and add UIRefreshControl to table view
        refreshControl = UIRefreshControl()
        refreshControl!.attributedTitle = NSAttributedString(string: "Pull down to refresh")
        tableView.addSubview(refreshControl!)
        tableView.alwaysBounceVertical = true
        self.refreshControl?.addTarget(self, action: #selector(refreshFiles), for: UIControlEvents.valueChanged)
        
        // Update sort control based on user preferences for sorting
        sortByControl.selectedSegmentIndex = PrintFile.defaultSortCriteria() == PrintFile.SortBy.alphabetical ? 0 : 1
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if currentTheme != Theme.currentTheme() {
            // Theme changed so repaint table now (to prevent quick flash in the UI with the old theme)
            tableView.reloadData()
            currentTheme = Theme.currentTheme()
        }

        if let printer = printerManager.getDefaultPrinter() {
            // Update window title to Camera name
            navigationItem.title = printer.name
            
            loadFiles(done: nil)
        }
        
        ThemeUIUtils.applyTheme(table: tableView, staticCells: false)
        applyTheme()
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
        return files.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let file = files[indexPath.row]
        
        if file.isFolder() {
            let cell = tableView.dequeueReusableCell(withIdentifier: "folder_cell", for: indexPath)
            cell.textLabel?.text = file.display
            
            return cell
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "file_cell", for: indexPath)
        cell.textLabel?.text = file.display
        cell.detailTextLabel?.text = file.displayOrigin()
        cell.imageView?.image = UIImage(named: file.isModel() ? "Model" : "GCode")
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return !files[indexPath.row].isFolder()
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete selected file
            self.deleteRow(forRowAt: indexPath)
            self.tableView.reloadData()
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        ThemeUIUtils.themeCell(cell: cell)
    }
    
    // MARK: - Unwind operations

    @IBAction func backFromDelete(_ sender: UIStoryboardSegue) {
        deleteRow(forRowAt: tableView.indexPathForSelectedRow!)
    }
    
    @IBAction func gobackToRootFolder(_ sender: UIStoryboardSegue) {
        // Files have been refreshed so just update UI
        self.tableView.reloadData()
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "gotoFileDetails" {
            if let controller = segue.destination as? FileDetailsViewController {
                controller.printFile = files[(tableView.indexPathForSelectedRow?.row)!]
            }
        } else if segue.identifier == "gotoFolder" {
            if let controller = segue.destination as? FolderViewController {
                controller.filesTreeVC = self
                controller.folder = files[(tableView.indexPathForSelectedRow?.row)!]
            }
        }
    }

    // MARK: - Button actions

    // Initialize SD card if needed and refresh files from SD card
    @IBAction func refreshSDCard(_ sender: Any) {
        octoprintClient.refreshSD { (success: Bool, error: Error?, response: HTTPURLResponse) in
            if success {
                // SD Card refreshed so now fetch files
                self.loadFiles(delay: 1)
            } else if response.statusCode == 409 {
                // SD Card is not initialized so initialize it now
                self.octoprintClient.initSD(callback: { (success: Bool, error: Error?, response: HTTPURLResponse) in
                    if success {
                        self.loadFiles(delay: 1)
                    } else {
                        self.showAlert("Alert", message: "Failed to initialize SD card", done: nil)
                    }
                })
            } else {
                self.showAlert("Alert", message: "Failed to refresh SD card", done: nil)
            }
        }
    }
    
    @IBAction func sortByChanged(_ sender: Any) {
        // Sort by new criteria
        if sortByControl.selectedSegmentIndex == 0 {
            files = PrintFile.resort(rootFiles: files, sortBy: PrintFile.SortBy.alphabetical)
        } else {
            files = PrintFile.resort(rootFiles: files, sortBy: PrintFile.SortBy.uploadDate)
        }
        // Refresh UI
        tableView.reloadData()
    }
    
    // MARK: - Refresh functions

    @objc func refreshFiles() {
        loadFiles(done: {
            DispatchQueue.main.async {
                self.refreshControl?.endRefreshing()
            }
        })
    }
    
    // Refresh files from OctoPrint and call me back with the refreshed file/folder that was specified
    func refreshFolderFiles(folder: PrintFile, callback: @escaping ((PrintFile?) -> Void)) {
        loadFiles(done: {
            for file in self.files {
                if let found = file.locate(file: folder) {
                    callback(found)
                    return
                }
            }
            // Could happen if folder no longer exists
            callback(nil)
        })
    }
    
    // MARK: - Theme functions
    
    fileprivate func applyTheme() {
        let theme = Theme.currentTheme()
        let tintColor = theme.tintColor()
        
        // Set background color to the view
        view.backgroundColor = theme.backgroundColor()
        // Set background color to the refresh SD button
        refreshSDButton.tintColor = tintColor
        // Set background color to the sort control
        sortByTextLabel.textColor = theme.labelColor()
        sortByControl.tintColor = tintColor
    }

    // MARK: - Private functions

    fileprivate func loadFiles(delay seconds: Double) {
        // Wait requested seconds before loading files (so SD card has time to be read)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            self.loadFiles(done: nil)
        }
    }
    
    fileprivate func loadFiles(done: (() -> Void)?) {
        // Load all files and folders (recursive)
        octoprintClient.files { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
            self.files = Array()
            // TODO Handle connection errors
            if let json = result as? NSDictionary {
                // OctoPrint uses 'files' field for root folder and 'children' for other folders
                if let files = json["files"] as? NSArray {
                    let trashRegEx = "^trash[-\\w]+~1\\/.+"
                    let trashTest = NSPredicate(format: "SELF MATCHES %@", trashRegEx)
                    
                    for case let file as NSDictionary in files {
                        let printFile = PrintFile()
                        printFile.parse(json: file)
                        
                        // Ignore files that are in the trash
                        if let path = printFile.path {
                            if trashTest.evaluate(with: path) {
                                continue
                            }
                        }
                        
                        // Keep track of files and folders
                        self.files.append(printFile)
                    }
                    
                    // Sort files by user prefered sort criteria
                    self.files = PrintFile.sort(files: self.files, sortBy: nil)
                }
            }
            // Refresh table (even if there was an error so it is empty)
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
            // Execute done block when done
            done?()
        }
    }
    
    fileprivate func deleteRow(forRowAt indexPath: IndexPath) {
        let printFile = files[indexPath.row]
        // Remove file from UI
        files.remove(at: indexPath.row)
        // Delete from server (if failed then show error message and reload)
        octoprintClient.deleteFile(origin: printFile.origin!, path: printFile.path!) { (success: Bool, error: Error?, response: HTTPURLResponse) in
            if !success {
                let message = response.statusCode == 409 ? "File currently being printed" : "Failed to delete file"
                self.showAlert("Alert", message: message, done: {
                    self.loadFiles(done: nil)
                })
            }
        }
    }
    
    fileprivate func showAlert(_ title: String, message: String, done: (() -> Void)?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: { (UIAlertAction) -> Void in
            // Execute done block on dismiss
            done?()
        }))
        // Present dialog on main thread to prevent crashes
        DispatchQueue.main.async {
            self.present(alert, animated: true) { () -> Void in
                // Nothing to do here
            }
        }
    }
}
