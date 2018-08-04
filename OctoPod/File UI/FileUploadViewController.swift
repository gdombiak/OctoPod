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
        
        sdCardLabel.isEnabled = false
        if let printer = printerManager.getDefaultPrinter(), let printeState = octoprintClient.lastKnownState {
            // Enable SD Card option only if printer has SD Card and is not printing
            let sdUsable = printer.sdSupport && printeState.printing != true
            sdCardLabel.isEnabled = sdUsable
            sdCardCell.isUserInteractionEnabled = sdUsable
        }
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
            showAlert("Warning", message: "Failed to read file from iCloud", done: nil)
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
                self.showAlert("Upload failed", message: "Invalid file type", done: {
                    self.dismiss(animated: false, completion: nil)
                })
            } else if response.statusCode == 404 {
                self.showAlert("Upload failed", message: "Location no longer valid. Refresh files", done: {
                    self.dismiss(animated: false, completion: nil)
                })
            } else if response.statusCode == 409 {
                self.showAlert("Upload failed", message: "Cannot replace file that is being printed or printer is busy", done: {
                    self.dismiss(animated: false, completion: nil)
                })
            } else if let e = error {
                self.showAlert("Upload failed", message: e.localizedDescription, done: {
                    self.dismiss(animated: false, completion: nil)
                })
            } else {
                self.showAlert("Upload failed", message: "Failed to upload file", done: {
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
            showAlert("Alert", message: "Enable iCloud under iOS Settings to use this feature", done: nil)
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
