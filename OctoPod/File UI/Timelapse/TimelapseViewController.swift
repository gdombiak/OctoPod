import UIKit
import AVKit

class TimelapseViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, DefaultPrinterManagerDelegate {

    private var currentTheme: Theme.ThemeChoice!

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()
    let defaultPrinterManager: DefaultPrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).defaultPrinterManager }()

    @IBOutlet weak var tableView: UITableView!
    var refreshControl: UIRefreshControl?

    var progressView: UIProgressView!
    var progressLabel: UILabel!

    var files: Array<Timelapse> = Array()

    var itemDelegate: AVAssetResourceLoaderDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Remember current theme so we know when to repaint
        currentTheme = Theme.currentTheme()

        // Create, configure and add UIRefreshControl to table view
        refreshControl = UIRefreshControl()
        tableView.addSubview(refreshControl!)
        tableView.alwaysBounceVertical = true
        self.refreshControl?.addTarget(self, action: #selector(refreshFiles), for: UIControl.Event.valueChanged)
        
        // Add Progress View
        progressView = UIProgressView(progressViewStyle: .bar)
        self.progressView.setProgress(0.5, animated: false)
        self.progressView.backgroundColor = UIColor.lightGray
        progressView.isHidden = true
        progressView.frame = CGRect(x: 40, y: view.frame.size.height / 2, width: view.frame.size.width - 80, height: 40)
        tableView.addSubview(progressView)
        NSLayoutConstraint.activate([
            progressView.centerXAnchor.constraint(equalTo: self.tableView.centerXAnchor),
            progressView.centerYAnchor.constraint(equalTo: self.tableView.centerYAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 45),
            progressView.widthAnchor.constraint(equalToConstant: 200)
        ])
        progressView.translatesAutoresizingMaskIntoConstraints = false

        // Add a progress label inside of Progress View (has enough height to show text)
        progressLabel = UILabel()
        progressLabel.font = UIFont.preferredFont(forTextStyle: .callout)
        progressLabel.isHidden = true
        progressView.addSubview(progressLabel)
        NSLayoutConstraint.activate([
            progressLabel.centerXAnchor.constraint(equalTo: self.progressView.centerXAnchor),
            progressLabel.centerYAnchor.constraint(equalTo: self.progressView.centerYAnchor),
        ])
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
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
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Stop listening to changes to default printer
        defaultPrinterManager.remove(defaultPrinterManagerDelegate: self)
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
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "timelapse_cell", for: indexPath)
        cell.textLabel?.text = file.name
        cell.detailTextLabel?.text = file.size

        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        ThemeUIUtils.themeCell(cell: cell)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let file = files[indexPath.row]
                
        if let printer = printerManager.getDefaultPrinter(), let path = file.url.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed), let url = URL(string: printer.hostname + path) {
            // Create AVPlayerItem object
            let headers = ["X-Api-Key": printer.apiKey]
            let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey" : headers])
            
            if let username = printer.username, let password = printer.password {
                itemDelegate = UIUtils.getAVAssetResourceLoaderDelegate(username: username, password: password)
                asset.resourceLoader.setDelegate(itemDelegate, queue:  DispatchQueue.global(qos: .userInitiated))
            }
            
            let playerItem = AVPlayerItem(asset: asset)
            // Register as an observer of the player item's status property
            playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status ), options: [.old, .new], context: nil)
            
            // Create AVPlayer object
            let player = AVPlayer(playerItem: playerItem)            
            
            let playerController = AVPlayerViewController()
            playerController.player = player
            
            present(playerController, animated: true) {
                player.play()
            }
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: NSLocalizedString("Delete", comment: "Delete action"), handler: { (action, view, completionHandler) in
            self.showConfirm(message: NSLocalizedString("Do you want to delete this file?", comment: "")) { (UIAlertAction) in
                let file = self.files[indexPath.row]
                // Delete timelapse from OctoPrint
                self.octoprintClient.deleteTimelapse(timelapse: file) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                    if let error = error {
                        self.showAlert(NSLocalizedString("Warning", comment: ""), message: error.localizedDescription) {
                            completionHandler(false)
                        }
                    } else {
                        // Remove timelapse from files and refresh table
                        self.files.remove(at: indexPath.row)
                        DispatchQueue.main.async {
                            tableView.deleteRows(at: [indexPath], with: .fade)
                        }
                        completionHandler(true)
                    }
                }
            } no: { (UIAlertAction) in
                completionHandler(false)
            }
          })
        if #available(iOS 13.0, *) {
            deleteAction.image = UIImage(systemName: "trash")
        } else {
            // Fallback on earlier versions
        }

        let shareAction = UIContextualAction(style: .normal, title: NSLocalizedString("Share", comment: "Share action"), handler: { (action, view, completionHandler) in
            // Update data source when user taps action
            let file = self.files[indexPath.row]
            // Display progress bar and reset it to zero
            self.progressView.setProgress(0, animated: false)
            self.progressView.isHidden = false
            self.progressLabel.text = "0 %"
            self.progressLabel.isHidden = false
            // Disable user interaction with the table so it cannot be refreshed or click on another cell to share another video
            tableView.isUserInteractionEnabled = false

            self.octoprintClient.downloadTimelapse(timelapse: file) { (totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) in
                // Update progress bar as download makes progress
                let progress = Float(totalBytesWritten) / Float(file.bytes)
                DispatchQueue.main.async {
                    self.progressView.setProgress(progress, animated: true)
                    self.progressLabel.text = "\(String(format: "%.1f", (progress * 100))) %"
                }
            } completion: { (data: Data?, error: Error?) in
                // Hide progress bar and reenable user interaction with the table
                DispatchQueue.main.async {
                    self.progressView.isHidden = true
                    self.progressLabel.isHidden = true
                    tableView.isUserInteractionEnabled = true
                }
                if let error = error {
                    self.showAlert(NSLocalizedString("Warning", comment: ""), message: error.localizedDescription) {
                        completionHandler(false)
                    }
                } else if let data = data {
                    // Write downloaded file into a filepath and return the filepath in NSURL
                    let fileURL = data.dataToFile(fileName: file.name)
                    let filesToShare = [fileURL]
                    DispatchQueue.main.async {
                        // Call from main thread so it does not crash on iPad
                        let activityViewController = UIActivityViewController(activityItems: filesToShare as [Any], applicationActivities: nil)
                        // Set sourceView so it does not crash on iPad
                        if UIDevice.current.userInterfaceIdiom == .pad {
                            activityViewController.popoverPresentationController?.sourceView = view
                            activityViewController.popoverPresentationController?.permittedArrowDirections = .any
                        }
                        self.present(activityViewController, animated: true) {
                            completionHandler(true)
                        }
                    }
                } else {
                    completionHandler(false)
                }
            }
          })
        if #available(iOS 13.0, *) {
            shareAction.image = UIImage(systemName: "square.and.arrow.up")
        } else {
            // Fallback on earlier versions
        }
        
        return UISwipeActionsConfiguration(actions: appConfiguration.appLocked() ? [shareAction] : [deleteAction, shareAction])
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(AVPlayerItem.status) {
            let status: AVPlayerItem.Status
            
            // Get the status change from the change dictionary
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItem.Status(rawValue: statusNumber.intValue)!
            } else {
                status = .unknown
            }
            
            // Switch over the status
            switch status {
            case .readyToPlay:
                break
            case .failed:
                NSLog("Player item failed.")
                if let playerItem = object as? AVPlayerItem, let error = playerItem.error {
                    NSLog("Player item error: \(error.localizedDescription)")
//                        self.stopPlaying()
//                    // Display error messages
//                    self.errorMessageLabel.text = error.localizedDescription
//                    self.errorMessageLabel.numberOfLines = 2
//                    self.errorURLButton.setTitle(self.cameraURL, for: .normal)
//                    self.errorMessageLabel.isHidden = false
//                    self.errorURLButton.isHidden = false
                }
            case .unknown:
                NSLog("Player item is not yet ready.")
            @unknown default:
                NSLog("Unkown status: \(status)")
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    // MARK: - DefaultPrinterManagerDelegate
    
    func defaultPrinterChanged() {
        DispatchQueue.main.async {
            self.refreshNewSelectedPrinter()
        }
    }
    
    // MARK: - Refresh functions

    @objc func refreshFiles() {
        loadFiles(done: nil)
    }
    
    // MARK: - Theme functions
    
    fileprivate func applyTheme() {
        let theme = Theme.currentTheme()
        
        // Set background color to the view
        view.backgroundColor = theme.backgroundColor()
        
        // Set color (and text) to refresh control
        if let refreshControl = refreshControl {
            ThemeUIUtils.applyTheme(refreshControl: refreshControl)
        }

        progressLabel.textColor = theme.labelColor()

        ThemeUIUtils.applyTheme(table: tableView, staticCells: false)
    }

    // MARK: - Private functions

    fileprivate func loadFiles(delay seconds: Double) {
        // Wait requested seconds before loading files (so SD card has time to be read)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            self.loadFiles(done: nil)
        }
    }
    
    fileprivate func loadFiles(done: (() -> Void)?) {
        // Refreshing files could take some time so show spinner of refreshing
        DispatchQueue.main.async {
            if let refreshControl = self.refreshControl {
                refreshControl.beginRefreshing()
                self.tableView.setContentOffset(CGPoint(x: 0, y: self.tableView.contentOffset.y - refreshControl.frame.size.height), animated: true)
            }
        }
        // Load all files and folders (recursive)
        octoprintClient.timelapses { (result: Array<Timelapse>?, error: Error?, response: HTTPURLResponse) in
            self.files = Array()
            // Handle connection errors
            if let error = error {
                self.showAlert(NSLocalizedString("Warning", comment: ""), message: error.localizedDescription, done: nil)
            } else if let newFiles = result {
                // Sort files by date (newest at the top)
                self.files = newFiles.sorted { (left: Timelapse, right: Timelapse) -> Bool in
                    return left.date > right.date
                }
            }
            // Refresh table (even if there was an error so it is empty)
            DispatchQueue.main.async {
                self.refreshControl?.endRefreshing()
                self.tableView.reloadData()
            }
            // Execute done block when done
            done?()
        }
    }

    fileprivate func refreshNewSelectedPrinter() {
        loadFiles(done: nil)
    }
    
    fileprivate func showAlert(_ title: String, message: String, done: (() -> Void)?) {
        UIUtils.showAlert(presenter: self, title: title, message: message, done: done)
    }

    fileprivate func showConfirm(message: String, yes: @escaping (UIAlertAction) -> Void, no: @escaping (UIAlertAction) -> Void) {
        UIUtils.showConfirm(presenter: self, message: message, yes: yes, no: no)
    }
}
