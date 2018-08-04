import UIKit

// VC that renders content of a folder
// Files were already fetched by FilesTreeViewController
class FolderViewController: ThemedDynamicUITableViewController, UIPopoverPresentationControllerDelegate {

    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()

    var filesTreeVC: FilesTreeViewController!
    var folder: PrintFile!
    var files: Array<PrintFile> = Array()  // Track files of the folder

    override func viewDidLoad() {
        super.viewDidLoad()        
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
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return files.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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

    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return !files[indexPath.row].isFolder()
    }

    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
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
                    var message = "Failed to request to print file"
                    if response.statusCode == 409 {
                        message = "Printer not operational"
                    } else if response.statusCode == 415 {
                        message = "Cannot print this file type"
                    }
                    self.showAlert("Alert", message: message, done: nil)
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
                    self.showAlert("SD Card", message: "File is being copied to SD Card", done: {
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
                let message = response.statusCode == 409 ? "File currently being printed" : "Failed to delete file"
                self.showAlert("Alert", message: message, done: {
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
