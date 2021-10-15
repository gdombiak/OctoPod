import UIKit

// VC that renders content of a folder
// Files were already fetched by FilesTreeViewController
class FolderViewController: ThemedDynamicUITableViewController, UIPopoverPresentationControllerDelegate, DefaultPrinterManagerDelegate, UISearchBarDelegate {

    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()
    let defaultPrinterManager: DefaultPrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).defaultPrinterManager }()

    @IBOutlet weak var searchBar: UISearchBar!

    // Gestures to switch between printers
    var swipeLeftGestureRecognizer : UISwipeGestureRecognizer!
    var swipeRightGestureRecognizer : UISwipeGestureRecognizer!

    var filesTreeVC: FilesTreeViewController!
    var folder: PrintFile!
    var files: Array<PrintFile> = Array()  // Track files of the folder
    var searching: Bool = false
    var searchedFiles: Array<PrintFile> = Array()

    override func viewDidLoad() {
        super.viewDidLoad()        
        // Listen to search bar events
        self.searchBar.delegate = self
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Update window title to folder we are browsing
        navigationItem.title = folder.display
        
        files = folder.children!
        
        // Refresh searched files
        self.updatedSearchedFiles(self.searchBar.text ?? "")

        // Clear selected row when going back to this VC
        if let selectionIndexPath = self.tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: selectionIndexPath, animated: animated)
        }

        // Listen to changes to default printer
        defaultPrinterManager.delegates.append(self)

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

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searching ? searchedFiles.count : files.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
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

    @IBAction func refreshFiles(_ sender: UIRefreshControl) {
        refreshFiles(refreshControl: sender)
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
        deleteRow(forRowAt: tableView.indexPathForSelectedRow!)
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
                    self.refreshFiles(refreshControl: nil)
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
                controller.filesTreeVC = filesTreeVC
                controller.folder = files[(tableView.indexPathForSelectedRow?.row)!]
            }
        } else if segue.identifier == "gotoUploadLocation" {
            if let controller = segue.destination as? FileUploadViewController {
                controller.popoverPresentationController!.delegate = self
                controller.currentFolder = folder // Indicate that it is being called from this folder
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
        // Go back to root folder since we have a new printer
        DispatchQueue.main.async {
            self.performSegue(withIdentifier: "gobackToRootFolder", sender: self)
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
    
    // MARK: - Theme functions
    
    fileprivate func applyTheme() {
        let theme = Theme.currentTheme()
        let textLabelColor = theme.labelColor()
        let tintColor = theme.tintColor()
        let textColor = theme.textColor()

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
        // Set color (and text) to refresh control
        if let refreshControl = refreshControl {
            ThemeUIUtils.applyTheme(refreshControl: refreshControl)
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
        // Remove from model in memory
        folder.children!.remove(at: indexPath.row)
        // Refresh UI
        self.tableView.reloadData()
        // Delete from server (if failed then show error message and reload)
        octoprintClient.deleteFile(origin: printFile.origin!, path: printFile.path!) { (success: Bool, error: Error?, response: HTTPURLResponse) in
            if !success {
                let message = response.statusCode == 409 ? NSLocalizedString("File currently being printed", comment: "") : NSLocalizedString("Failed to delete file", comment: "")
                self.showAlert(NSLocalizedString("Warning", comment: ""), message: message, done: {
                    // Refresh UI
                    DispatchQueue.main.async {
                        // Add back file to UI
                        self.files.append(printFile)
                        // Add back to model in memory
                        self.folder.children!.append(printFile)
                        // Refresh searched files
                        self.updatedSearchedFiles(self.searchBar.text ?? "")
                        self.tableView.reloadData()
                    }
                })
            }
        }
    }
    
    fileprivate func refreshFiles(refreshControl: UIRefreshControl?) {
        filesTreeVC.refreshFolderFiles(folder: folder) { (updatedFile: PrintFile?) in
            if let updated = updatedFile {
                DispatchQueue.main.async {
                    self.folder = updated
                    self.files = updated.children!
                    // Refresh searched files
                    self.updatedSearchedFiles(self.searchBar.text ?? "")
                    self.tableView.reloadData()
                    refreshControl?.endRefreshing()
                }
            } else {
                // Go back to root folder since folder no longer exists
                DispatchQueue.main.async {
                    self.performSegue(withIdentifier: "gobackToRootFolder", sender: self)
                }
            }
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
