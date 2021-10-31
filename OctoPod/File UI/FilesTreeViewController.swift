import UIKit

class FilesTreeViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UIPopoverPresentationControllerDelegate, DefaultPrinterManagerDelegate, UISearchBarDelegate {
    
    private var currentTheme: Theme.ThemeChoice!

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()
    let defaultPrinterManager: DefaultPrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).defaultPrinterManager }()

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var sortByTextLabel: UILabel!
    @IBOutlet weak var sortByControl: UISegmentedControl!
    @IBOutlet weak var refreshSDButton: UIButton!
    var refreshControl: UIRefreshControl?

    // Gestures to switch between printers
    var swipeLeftGestureRecognizer : UISwipeGestureRecognizer!
    var swipeRightGestureRecognizer : UISwipeGestureRecognizer!

    var files: Array<PrintFile> = Array()
    var searching: Bool = false
    var searchedFiles: Array<PrintFile> = Array()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Remember current theme so we know when to repaint
        currentTheme = Theme.currentTheme()

        // Create, configure and add UIRefreshControl to table view
        refreshControl = UIRefreshControl()
        tableView.addSubview(refreshControl!)
        tableView.alwaysBounceVertical = true
        self.refreshControl?.addTarget(self, action: #selector(refreshFiles), for: UIControl.Event.valueChanged)
        
        // Listen to search bar events
        self.searchBar.delegate = self
        
        // Update sort control based on user preferences for sorting
        var selectIndex = 0
        switch PrintFile.defaultSortCriteria() {
        case PrintFile.SortBy.alphabetical:
            selectIndex = 0
        case PrintFile.SortBy.uploadDate:
            selectIndex = 1
        case PrintFile.SortBy.lastPrintDate:
            selectIndex = 2
        }
        sortByControl.selectedSegmentIndex = selectIndex
        
        // Check if we should hide sortByTextLabel due to small screen
        let devicePortrait = UIApplication.shared.statusBarOrientation.isPortrait
        let screenHeight = devicePortrait ? UIScreen.main.bounds.height : UIScreen.main.bounds.width
        if screenHeight <= 568 {
            // iPhone 5, 5s, 5c, SE
            sortByTextLabel.isHidden = true
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Listen to changes to default printer
        defaultPrinterManager.delegates.append(self)

        if currentTheme != Theme.currentTheme() {
            // Theme changed so repaint table now (to prevent quick flash in the UI with the old theme)
            tableView.reloadData()
            currentTheme = Theme.currentTheme()
        }

        refreshNewSelectedPrinter()
        
        ThemeUIUtils.applyTheme(table: tableView, staticCells: false)
        applyTheme()

        // Add gestures to capture swipes and taps on navigation bar
        addNavBarGestures()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Stop listening to changes to default printer
        defaultPrinterManager.remove(defaultPrinterManagerDelegate: self)
        // Remove gestures that capture swipes and taps on navigation bar
        removeNavBarGestures()
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
        return searching ? searchedFiles.count : files.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let theme = Theme.currentTheme()
        let textColor = theme.textColor()
        
        let files = searching ? searchedFiles : self.files
        let file = files[indexPath.row]
        
        if file.isFolder() {
            let cell = tableView.dequeueReusableCell(withIdentifier: "folder_cell", for: indexPath)
            if let fileLabel = cell.viewWithTag(100) as? UILabel {
                fileLabel.text = file.display
                fileLabel.textColor = textColor
            }
            
            return cell
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "file_cell", for: indexPath)
        if let fileLabel = cell.viewWithTag(100) as? UILabel {
            fileLabel.text = file.display
            if let success = file.lastSuccessfulPrint {
                fileLabel.textColor = success ? UIColor(red: 70/255, green: 136/255, blue: 71/255, alpha: 1.0) : UIColor(red: 185/255, green: 74/255, blue: 72/255, alpha: 1.0)
            } else {
                // Use theme color since there is no info about last successful print
                fileLabel.textColor = textColor
            }
        }
        if let originLabel = cell.viewWithTag(200) as? UILabel {
            originLabel.text = file.displayOrigin()
            originLabel.textColor = textColor
        }
        if let dateLabel = cell.viewWithTag(201) as? UILabel {
            dateLabel.text = file.date?.timeAgoDisplay()
            dateLabel.textColor = textColor
        }
        if let sizeLabel = cell.viewWithTag(202) as? UILabel {
            var displaySize = file.displaySize()
            let textLength = displaySize.count
            if textLength < 10 {
                displaySize = String(repeating: " ", count: 10 - textLength) + displaySize
            }
            sizeLabel.text = displaySize
            sizeLabel.textColor = textColor
        }
        if let imageView = cell.viewWithTag(50) as? UIImageView {
            imageView.image = UIImage(named: file.isModel() ? "Model_48" : "GCode_48")
            if let thumbnailURL = file.thumbnail {
                octoprintClient.getThumbnailImage(path: thumbnailURL) { (data: Data?, error: Error?, response: HTTPURLResponse) in
                    if let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            if let resizedImaged = image.resizeWithWidth(width: 48) {
                                imageView.image = resizedImaged
                            }
                        }
                    }
                }
            }
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: NSLocalizedString("Delete", comment: "Delete action"), handler: { (action, view, completionHandler) in
            self.showConfirm(message: NSLocalizedString("Do you want to delete this file?", comment: "")) { (UIAlertAction) in
                // Delete selected file
                self.deleteRow(forRowAt: indexPath)
                self.tableView.reloadData()
                completionHandler(true)
            } no: { (UIAlertAction) in
                completionHandler(false)
            }
          })
        if #available(iOS 13.0, *) {
            deleteAction.image = UIImage(systemName: "trash")
        } else {
            // Fallback on earlier versions
        }

        let files = searching ? searchedFiles : self.files
        let canDelete = indexPath.row < files.count && !files[indexPath.row].isFolder() && !appConfiguration.appLocked()
        return UISwipeActionsConfiguration(actions: !canDelete ? [] : [deleteAction])
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        ThemeUIUtils.themeCell(cell: cell)
    }
    
    // MARK: - Unwind operations

    @IBAction func backFromPrint(_ sender: UIStoryboardSegue) {
        if let row = tableView.indexPathForSelectedRow?.row {
            let files = searching ? searchedFiles : self.files
            let printFile = files[row]
            // Request to print file
            octoprintClient.printFile(origin: printFile.origin!, path: printFile.path!) { (success: Bool, error: Error?, response: HTTPURLResponse) in
                if !success {
                    var message = NSLocalizedString("Failed to request to print file", comment: "")
                    if response.statusCode == 409 {
                        message = NSLocalizedString("Printer not operational", comment: "")
                    } else if response.statusCode == 415 {
                        message = NSLocalizedString("Cannot print this file type", comment: "")
                    }
                    self.showAlert(NSLocalizedString("Warning", comment: ""), message: message, done: nil)
                } else {
                    // Request to print file was successful so go to print window
                    DispatchQueue.main.async {
                        self.tabBarController?.selectedIndex = 0
                    }
                }
            }
        }
    }

    @IBAction func backFromDelete(_ sender: UIStoryboardSegue) {
        if let row = tableView.indexPathForSelectedRow {
            deleteRow(forRowAt: row)
        }
    }
    
    @IBAction func gobackToRootFolder(_ sender: UIStoryboardSegue) {
        // Files have been refreshed so just update UI
        self.tableView.reloadData()
    }
    
    @IBAction func backFromUploadFile(_ sender: UIStoryboardSegue) {
        if let controller = sender.source as? FileUploadViewController {
            if controller.uploaded {
                if controller.selectedLocation == CloudFilesManager.Location.SDCard {
                    // File is in OctoPrint and is being copied to SD Card so send user to main page
                    self.showAlert(NSLocalizedString("SD Card", comment: ""), message: NSLocalizedString("File is being copied to SD Card", comment: ""), done: {
                        self.tabBarController?.selectedIndex = 0
                    })
                } else {
                    // Refresh files since file was uploaded
                    self.loadFiles(done: nil)
                }
            }
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let files = searching ? searchedFiles : self.files
        if segue.identifier == "gotoFileDetails" {
            if let controller = segue.destination as? FileDetailsViewController {
                controller.printFile = files[(tableView.indexPathForSelectedRow?.row)!]
            }
        } else if segue.identifier == "gotoFolder" {
            if let controller = segue.destination as? FolderViewController {
                controller.filesTreeVC = self
                controller.folder = files[(tableView.indexPathForSelectedRow?.row)!]
            }
        } else if segue.identifier == "gotoUploadLocation" {
            if let controller = segue.destination as? FileUploadViewController {
                controller.popoverPresentationController!.delegate = self
                controller.currentFolder = nil // Indicate that it is being called from root folder
            }
        }
    }

    // MARK: - UIPopoverPresentationControllerDelegate
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }
    
    // We need to add this so it works on iPhone plus in landscape mode
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }
    
    // MARK: - DefaultPrinterManagerDelegate
    
    func defaultPrinterChanged() {
        DispatchQueue.main.async {
            self.refreshNewSelectedPrinter()
        }
    }
    
    // MARK: - UISearchBarDelegate
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searching = !searchText.isEmpty
        updatedSearchedFiles(searchText)
        tableView.reloadData()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        // Hide keyboard but leave cancel button enabled (if there is search text)
        searchBar.endEditing(true)
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searching = false
        updatedSearchedFiles("")
        searchBar.text = ""
        searchBar.endEditing(true)
        tableView.reloadData()
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
                        self.showAlert(NSLocalizedString("Warning", comment: ""), message: NSLocalizedString("Failed to initialize SD card", comment: ""), done: nil)
                    }
                })
            } else {
                self.showAlert(NSLocalizedString("Warning", comment: ""), message: NSLocalizedString("Failed to refresh SD card", comment: ""), done: nil)
            }
        }
    }
    
    @IBAction func sortByChanged(_ sender: Any) {
        // Sort by new criteria
        if sortByControl.selectedSegmentIndex == 0 {
            files = PrintFile.resort(rootFiles: files, sortBy: PrintFile.SortBy.alphabetical)
            searchedFiles = PrintFile.resort(rootFiles: searchedFiles, sortBy: PrintFile.SortBy.alphabetical)
        } else if sortByControl.selectedSegmentIndex == 1 {
            files = PrintFile.resort(rootFiles: files, sortBy: PrintFile.SortBy.uploadDate)
            searchedFiles = PrintFile.resort(rootFiles: searchedFiles, sortBy: PrintFile.SortBy.uploadDate)
        } else {
            files = PrintFile.resort(rootFiles: files, sortBy: PrintFile.SortBy.lastPrintDate)
            searchedFiles = PrintFile.resort(rootFiles: searchedFiles, sortBy: PrintFile.SortBy.lastPrintDate)
        }
        // Refresh UI
        tableView.reloadData()
    }
    
    // MARK: - Refresh functions

    @objc func refreshFiles() {
        loadFiles(done: nil)
    }
    
    // Refresh files from OctoPrint and call me back with the refreshed file/folder that was specified
    func refreshFolderFiles(folder: PrintFile, callback: @escaping ((PrintFile?) -> Void)) {
        loadFiles(done: { newFiles in
            for file in newFiles {
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
        let textLabelColor = theme.labelColor()
        let tintColor = theme.tintColor()
        let textColor = theme.textColor()

        // Set background color to the view
        view.backgroundColor = theme.backgroundColor()
        // Set background color to the refresh SD button
        refreshSDButton.setTitleColor(tintColor, for: .normal)
        // Set color (and text) to refresh control
        if let refreshControl = refreshControl {
            ThemeUIUtils.applyTheme(refreshControl: refreshControl)
        }
        // Set background color to the sort control
        sortByTextLabel.textColor = textLabelColor
        sortByControl.tintColor = tintColor
        // Theme search bar
        searchBar.barTintColor = theme.backgroundColor()
        let disabledColor = tintColor.withAlphaComponent(0.35)
        UIBarButtonItem.appearance(whenContainedInInstancesOf: [UISearchBar.self]).setTitleTextAttributes([.foregroundColor: tintColor], for: .normal)
        UIBarButtonItem.appearance(whenContainedInInstancesOf: [UISearchBar.self]).setTitleTextAttributes([.foregroundColor: disabledColor], for: .disabled)
        if #available(iOS 13.0, *) {
            let searchTextField = self.searchBar.searchTextField
            searchTextField.textColor = textColor
            if let iconView = searchTextField.leftView {
                iconView.tintColor = textLabelColor
            }
        } else {
            // Fallback on earlier versions
            if let textField = searchBar.value(forKey: "searchField") as? UITextField {
                textField.textColor = textColor
                if let iconView = textField.leftView as? UIImageView {
                    //Magnifying glass
                    iconView.tintColor = textLabelColor
                }
            }
        }
    }

    // MARK: - Private - Navigation Bar Gestures

    fileprivate func addNavBarGestures() {
        // Add gesture when we swipe from right to left
        swipeLeftGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(navigationBarSwiped(_:)))
        swipeLeftGestureRecognizer.direction = .left
        navigationController?.navigationBar.addGestureRecognizer(swipeLeftGestureRecognizer)
        swipeLeftGestureRecognizer.cancelsTouchesInView = false
        
        // Add gesture when we swipe from left to right
        swipeRightGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(navigationBarSwiped(_:)))
        swipeRightGestureRecognizer.direction = .right
        navigationController?.navigationBar.addGestureRecognizer(swipeRightGestureRecognizer)
        swipeRightGestureRecognizer.cancelsTouchesInView = false
    }

    fileprivate func removeNavBarGestures() {
        // Remove gesture when we swipe from right to left
        navigationController?.navigationBar.removeGestureRecognizer(swipeLeftGestureRecognizer)
        
        // Remove gesture when we swipe from left to right
        navigationController?.navigationBar.removeGestureRecognizer(swipeRightGestureRecognizer)
    }

    @objc fileprivate func navigationBarSwiped(_ gesture: UIGestureRecognizer) {
        // Change default printer
        let direction: DefaultPrinterManager.SwipeDirection = gesture == swipeLeftGestureRecognizer ? .left : .right
        defaultPrinterManager.navigationBarSwiped(direction: direction)
    }

    // MARK: - Private functions

    fileprivate func loadFiles(delay seconds: Double) {
        // Wait requested seconds before loading files (so SD card has time to be read)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            self.loadFiles(done: nil)
        }
    }
    
    fileprivate func loadFiles(done: ((Array<PrintFile>) -> Void)?) {
        // Refreshing files could take some time so show spinner of refreshing
        DispatchQueue.main.async {
            if let refreshControl = self.refreshControl {
                refreshControl.beginRefreshing()
                self.tableView.setContentOffset(CGPoint(x: 0, y: self.tableView.contentOffset.y - refreshControl.frame.size.height), animated: true)
            }
        }
        // Load all files and folders (recursive)
        octoprintClient.files { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
            var newFiles: Array<PrintFile> = Array()
            // Handle connection errors
            if let error = error {
                self.showAlert(NSLocalizedString("Warning", comment: ""), message: error.localizedDescription, done: nil)
            } else if let json = result as? NSDictionary {
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
                        
                        // Check if we should ignore files that are not gcodes
                        if self.appConfiguration.filesOnlyGCode() && printFile.isModel() {
                            continue
                        }
                        
                        // Keep track of files and folders
                        newFiles.append(printFile)
                    }
                    
                    // Sort files by user prefered sort criteria
                    newFiles = PrintFile.sort(files: newFiles, sortBy: nil)
                }
            }
            // Refresh table (even if there was an error so it is empty)
            DispatchQueue.main.async {
                self.files = newFiles
                // Refresh searched files
                self.updatedSearchedFiles(self.searchBar.text ?? "")
                // Close refresh control
                self.refreshControl?.endRefreshing()
                self.tableView.reloadData()
            }
            // Execute done block when done
            done?(newFiles)
        }
    }
    
    fileprivate func deleteRow(forRowAt indexPath: IndexPath) {
        let printFile: PrintFile!
        if searching {
            printFile = searchedFiles[indexPath.row]
            // Remove file from UI
            searchedFiles.remove(at: indexPath.row)
            files.removeAll { (someFile: PrintFile) -> Bool in
                return someFile == printFile
            }
        } else {
            printFile = files[indexPath.row]
            // Remove file from UI
            files.remove(at: indexPath.row)
        }
        
        // Delete from server (if failed then show error message and reload)
        octoprintClient.deleteFile(origin: printFile.origin!, path: printFile.path!) { (success: Bool, error: Error?, response: HTTPURLResponse) in
            if !success {
                let message = response.statusCode == 409 ? NSLocalizedString("File currently being printed", comment: "") : NSLocalizedString("Failed to delete file", comment: "")
                self.showAlert(NSLocalizedString("Warning", comment: ""), message: message, done: {
                    self.loadFiles(done: nil)
                })
            }
        }
    }
    
    fileprivate func refreshNewSelectedPrinter() {
        if let printer = printerManager.getDefaultPrinter() {
            // Update window title to Camera name
            navigationItem.title = printer.name
            
            // Only enable refresh SD buttom if printer has an SD card
            refreshSDButton.isEnabled = printer.sdSupport && !appConfiguration.appLocked()
            
            loadFiles(done: nil)
        }
    }
    
    fileprivate func updatedSearchedFiles(_ searchText: String) {
        if searchText.isEmpty {
            searchBar.setShowsCancelButton(false, animated: false)
            searchedFiles = Array()
        } else {
            searchBar.setShowsCancelButton(true, animated: false)
            searchedFiles = files.filter { $0.display.lowercased().contains(searchText.lowercased()) }
        }
    }
    
    fileprivate func showAlert(_ title: String, message: String, done: (() -> Void)?) {
        UIUtils.showAlert(presenter: self, title: title, message: message, done: done)
    }

    fileprivate func showConfirm(message: String, yes: @escaping (UIAlertAction) -> Void, no: @escaping (UIAlertAction) -> Void) {
        UIUtils.showConfirm(presenter: self, message: message, yes: yes, no: no)
    }
}
