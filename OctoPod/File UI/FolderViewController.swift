import UIKit

// VC that renders content of a folder
// Files were already fetched by FilesTreeViewController
class FolderViewController: ThemedDynamicUITableViewController, UIPopoverPresentationControllerDelegate, WatchSessionManagerDelegate {

    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()
    let watchSessionManager: WatchSessionManager = { return (UIApplication.shared.delegate as! AppDelegate).watchSessionManager }()

    var filesTreeVC: FilesTreeViewController!
    var folder: PrintFile!
    var files: Array<PrintFile> = Array()  // Track files of the folder

    override func viewDidLoad() {
        super.viewDidLoad()        
        // Some bug in XCode Storyboards is not translating text of refresh control so let's do it manually
        self.refreshControl?.attributedTitle = NSAttributedString(string: NSLocalizedString("Pull down to refresh", comment: ""))
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
        
        // Clear selected row when going back to this VC
        if let selectionIndexPath = self.tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: selectionIndexPath, animated: animated)
        }

        // Listen to changes coming from Apple Watch
        watchSessionManager.delegates.append(self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Stop listening to changes coming from Apple Watch
        watchSessionManager.remove(watchSessionManagerDelegate: self)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return files.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let theme = Theme.currentTheme()
        let textColor = theme.textColor()

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
            fileLabel.textColor = textColor
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

    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if indexPath.row < files.count {
            return !files[indexPath.row].isFolder() && !appConfiguration.appLocked()
        }
        return false
    }

    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete selected file
            self.deleteRow(forRowAt: indexPath)
            self.tableView.reloadData()
        }
    }
    
    @IBAction func refreshFiles(_ sender: UIRefreshControl) {
        refreshFiles(refreshControl: sender)
    }
    
    // MARK: - Unwind operations
    
    @IBAction func backFromPrint(_ sender: UIStoryboardSegue) {
        if let row = tableView.indexPathForSelectedRow?.row {
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
    
    // MARK: - WatchSessionManagerDelegate
    
    // Notification that a new default printer has been selected from the Apple Watch app
    func defaultPrinterChanged() {
        // Go back to root folder since we have a new printer
        DispatchQueue.main.async {
            self.performSegue(withIdentifier: "gobackToRootFolder", sender: self)
        }
    }
    
    // MARK: - Private functions
    
    fileprivate func deleteRow(forRowAt indexPath: IndexPath) {
        let printFile = files[indexPath.row]
        // Remove file from UI
        files.remove(at: indexPath.row)
        // Remove from model in memory
        folder.children!.remove(at: indexPath.row)
        // Refresh UI
        self.tableView.reloadData()
        // Delete from server (if failed then show error message and reload)
        octoprintClient.deleteFile(origin: printFile.origin!, path: printFile.path!) { (success: Bool, error: Error?, response: HTTPURLResponse) in
            if !success {
                let message = response.statusCode == 409 ? NSLocalizedString("File currently being printed", comment: "") : NSLocalizedString("Failed to delete file", comment: "")
                self.showAlert(NSLocalizedString("Warning", comment: ""), message: message, done: {
                    // Add back file to UI
                    self.files.append(printFile)
                    // Add back to model in memory
                    self.folder.children!.append(printFile)
                    // Refresh UI
                    DispatchQueue.main.async { self.tableView.reloadData() }
                })
            }
        }
    }
    
    fileprivate func refreshFiles(refreshControl: UIRefreshControl?) {
        filesTreeVC.refreshFolderFiles(folder: folder) { (updatedFile: PrintFile?) in
            if let updated = updatedFile {
                self.folder = updated
                self.files = updated.children!
                DispatchQueue.main.async {
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
    
    fileprivate func showAlert(_ title: String, message: String, done: (() -> Void)?) {
        UIUtils.showAlert(presenter: self, title: title, message: message, done: done)
    }
}
