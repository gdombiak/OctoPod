import UIKit

// Ask user if they want to upload file to SD card of current folder
class FileUploadViewController: UITableViewController, UIDocumentPickerDelegate {
    
    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    let cloudFilesManager: CloudFilesManager = { return (UIApplication.shared.delegate as! AppDelegate).cloudFilesManager }()

    @IBOutlet weak var sdCardCell: UITableViewCell!
    @IBOutlet weak var sdCardLabel: UILabel!
    
    @IBOutlet weak var uploadingOctoPrintLabel: UILabel!
    @IBOutlet weak var uploadingSDCardLabel: UILabel!
    

    var currentFolder: PrintFile? // Folder that user is browsing. If nil then this is root folder. This folder is used only when uploading to OctoPrint (not SD Card)
    var selectedLocation: CloudFilesManager.Location? // Track where user selected to upload file (OctoPrint or SD Card)
    var uploaded: Bool = false  // Track if file was successfully uploaded (to OctoPrint or SD Card)

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // Hide uploading labels
        uploadingOctoPrintLabel.isHidden = true
        uploadingSDCardLabel.isHidden = true

        // Clean up any previous selection
        uploaded = false
        
        // Disable upload to SD Card by default
        sdCardLabel.isEnabled = false
        sdCardCell.selectionStyle = .none
        if let printer = printerManager.getDefaultPrinter(), let printeState = octoprintClient.lastKnownState {
            // Enable SD Card option only if printer has SD Card and is not printing
            let sdUsable = printer.sdSupport && printeState.printing != true && printeState.closedOrError == false
            sdCardLabel.isEnabled = sdUsable
            sdCardCell.selectionStyle = sdUsable ? .default : .none
        }
    }
    
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if let cell = tableView.cellForRow(at: indexPath) {
            if cell.selectionStyle != .none {
                return indexPath
            }
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            // User selected to upload to current folder
            selectedLocation = CloudFilesManager.Location.OctoPrint
        } else {
            // User selected to upload to SD Card
            selectedLocation = CloudFilesManager.Location.SDCard
        }
        // Present window with iCloud files so user can select
        selectFileToUpload()
    }

    // MARK: - UIDocumentPickerDelegate
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        for url in urls {
            processFile(url: url)
        }
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        processFile(url: url)
    }
    
    // MARK: - Private functions
    
    fileprivate func processFile(url: URL) {
        let isSecured = url.startAccessingSecurityScopedResource() == true
        guard let fileData = try? Data(contentsOf: url) else {
            showAlert(NSLocalizedString("Warning", comment: ""), message: NSLocalizedString("Failed to read file from iCloud", comment: ""), done: nil)
            return
        }
        
        if isSecured {
            url.stopAccessingSecurityScopedResource()
        }
        
        let callback = { (uploaded: Bool, error: Error?, response: HTTPURLResponse) in
            // Update whether file was successfully uploaded or not
            self.uploaded = uploaded
            if uploaded {
                // Go back to previous screen
                DispatchQueue.main.async {
                    self.uploadingOctoPrintLabel.layer.removeAllAnimations()
                    self.uploadingSDCardLabel.layer.removeAllAnimations()
                    self.performSegue(withIdentifier: "backFromUploadFile", sender: self)
                }
            } else if response.statusCode == 400 {
                self.showAlert(NSLocalizedString("Upload failed", comment: ""), message: NSLocalizedString("Invalid file type", comment: ""), done: {
                    self.dismiss(animated: false, completion: nil)
                })
            } else if response.statusCode == 404 {
                self.showAlert(NSLocalizedString("Upload failed", comment: ""), message: NSLocalizedString("Location no longer valid. Refresh files", comment: ""), done: {
                    self.dismiss(animated: false, completion: nil)
                })
            } else if response.statusCode == 409 {
                self.showAlert(NSLocalizedString("Upload failed", comment: ""), message: NSLocalizedString("Cannot replace file that is being printed or printer is busy", comment: ""), done: {
                    self.dismiss(animated: false, completion: nil)
                })
            } else if let e = error {
                self.showAlert(NSLocalizedString("Upload failed", comment: ""), message: e.localizedDescription, done: {
                    self.dismiss(animated: false, completion: nil)
                })
            } else {
                self.showAlert(NSLocalizedString("Upload failed", comment: ""), message: NSLocalizedString("Failed to upload file", comment: ""), done: {
                    self.dismiss(animated: false, completion: nil)
                })
            }
        }
        
        if selectedLocation == CloudFilesManager.Location.OctoPrint {
            DispatchQueue.main.async {
                self.animateUploading(label: self.uploadingOctoPrintLabel)
            }
            octoprintClient.uploadFileToOctoPrint(folder: currentFolder, filename: url.lastPathComponent, fileContent: fileData, callback: callback)
        } else {
            DispatchQueue.main.async {
                self.animateUploading(label: self.uploadingSDCardLabel)
            }
            octoprintClient.uploadFileToSDCard(filename: url.lastPathComponent, fileContent: fileData, callback: callback)
        }
    }
    
    fileprivate func selectFileToUpload() {
        if let _ = cloudFilesManager.containerUrl {
            let picker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .open)
            picker.delegate = self
            picker.modalPresentationStyle = .fullScreen
            self.present(picker, animated: false, completion: nil)
        } else {
            showAlert(NSLocalizedString("Warning", comment: ""), message: NSLocalizedString("Enable iCloud under iOS Settings to use this feature", comment: ""), done: nil)
        }
    }
    
    fileprivate func animateUploading(label: UILabel) {
        // Make label visible
        label.isHidden = false
        // Start animating the label
        UIView.animate(withDuration: 0.7, delay: 0.5, options: [.repeat, .autoreverse], animations: {
            label.alpha = 0
        }, completion: nil)
    }
    
    fileprivate func showAlert(_ title: String, message: String, done: (() -> Void)?) {
        UIUtils.showAlert(presenter: self, title: title, message: message, done: done)
    }

}
