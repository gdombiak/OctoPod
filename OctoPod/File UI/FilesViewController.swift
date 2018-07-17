import UIKit

class FilesViewController: UITableViewController {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    
    var files: Array<PrintFile>?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if let printer = printerManager.getDefaultPrinter() {
            // Update window title to Camera name
            navigationItem.title = printer.name
            
            loadFiles(done: nil)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return files == nil ? 0 : files!.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "file_cell", for: indexPath)

        cell.textLabel?.text = files?[indexPath.row].display
        cell.detailTextLabel?.text = files?[indexPath.row].displayOrigin()

        return cell
    }

    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            deleteRow(forRowAt: indexPath)
            tableView.reloadData()
        }
    }

    @IBAction func refreshFiles(_ sender: UIRefreshControl) {
        loadFiles(done: {
            DispatchQueue.main.async {
                sender.endRefreshing()
            }
        })
    }
    
    // Initialize SD card if needed and refresh files from SD card
    @IBAction func refreshSDCard(_ sender: Any) {
        octoprintClient.refreshSD { (success: Bool, error: Error?, response: HTTPURLResponse) in
            if success {
                // SD Card refreshed so now fetch files
                self.loadFiles(done: nil)
            } else if response.statusCode == 409 {
                // SD Card is not initialized so initialize it now
                self.octoprintClient.initSD(callback: { (success: Bool, error: Error?, response: HTTPURLResponse) in
                    if success {
                        self.loadFiles(done: nil)
                    } else {
                        self.showAlert("Alert", message: "Failed to initialize SD card", done: nil)
                    }
                })
            } else {
                self.showAlert("Alert", message: "Failed to refresh SD card", done: nil)
            }
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "gotoFileDetails" {
            if let controller = segue.destination as? FileDetailsViewController {
                controller.printFile = files?[(tableView.indexPathForSelectedRow?.row)!]
            }
        }
    }
    
    @IBAction func backFromPrint(_ sender: UIStoryboardSegue) {
        if let printFile = files?[(tableView.indexPathForSelectedRow?.row)!] {
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

    // MARK: - Private functions
    
    fileprivate func loadFiles(done: (() -> Void)?) {
        self.octoprintClient.files { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
            self.files = Array()
            // TODO Handle connection errors
            if let json = result as? NSDictionary {
                if let files = json["files"] as? NSArray {
                    let trashRegEx = "^trash[-\\w]+~1\\/.+"
                    let trashTest = NSPredicate(format: "SELF MATCHES %@", trashRegEx)

                    for case let file as NSDictionary in files {
                        let printFile = PrintFile()
                        printFile.parse(json: file)
                        
                        if let path = printFile.path {
                            if trashTest.evaluate(with: path) {
                                continue
                            }
                        }

                        // Only add files that are not folders
                        if printFile.type != "folder" {
                            self.files?.append(printFile)
                        }
                    }
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
        if let printFile = files?[indexPath.row] {
            // Remove file from UI
            files?.remove(at: indexPath.row)
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
    }

    fileprivate func showAlert(_ title: String, message: String, done: (() -> Void)?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: { (UIAlertAction) -> Void in
            // Execute done block on dismiss
            done?()
        }))
        self.present(alert, animated: true) { () -> Void in
            // Nothing to do here
        }
    }
}
