import UIKit

// Ask user if they want to upload file to SD card of current folder
class FileUploadViewController: ThemedStaticUITableViewController, UIDocumentPickerDelegate {
    let printerManager: PrinterManager = (UIApplication.shared.delegate as! AppDelegate).printerManager!
    let octoprintClient: OctoPrintClient = (UIApplication.shared.delegate as! AppDelegate).octoprintClient
    let cloudFilesManager: CloudFilesManager = (UIApplication.shared.delegate as! AppDelegate).cloudFilesManager

    @IBOutlet var uploadOctoPrintLabel: UILabel!

    @IBOutlet var sdCardCell: UITableViewCell!
    @IBOutlet var sdCardLabel: UILabel!

    @IBOutlet var uploadingOctoPrintImage: UIImageView!
    @IBOutlet var uploadingSDCardImage: UIImageView!

    var currentFolder: PrintFile? // Folder that user is browsing. If nil then this is root folder. This folder is used only when uploading to OctoPrint (not SD Card)
    var selectedLocation: CloudFilesManager.Location? // Track where user selected to upload file (OctoPrint or SD Card)
    var uploaded: Bool = false // Track if file was successfully uploaded (to OctoPrint or SD Card)
    var uploadURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Hide uploading labels
        uploadingOctoPrintImage.isHidden = true
        uploadingSDCardImage.isHidden = true

        // Theme color of labels
        let theme = Theme.currentTheme()
        uploadOctoPrintLabel.textColor = theme.labelColor()
        sdCardLabel.textColor = theme.labelColor()
        // Set background color of popover and its arrow
        popoverPresentationController?.backgroundColor = theme.backgroundColor()

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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Adjust popover size to table size
        preferredContentSize.height = tableView.contentSize.height
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
        // Is already an uploadURL selected via openURL ?
        if let uploadURL = uploadURL {
            // Yes, so use that
            processFile(url: uploadURL)
        } else {
            // Present window with iCloud files so user can select
            selectFileToUpload()
        }
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
                    self.uploadingOctoPrintImage.layer.removeAllAnimations()
                    self.uploadingSDCardImage.layer.removeAllAnimations()
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
                self.animateUploading(image: self.uploadingOctoPrintImage)
            }
            octoprintClient.uploadFileToOctoPrint(folder: currentFolder, filename: url.lastPathComponent, fileContent: fileData, callback: callback)
        } else {
            DispatchQueue.main.async {
                self.animateUploading(image: self.uploadingSDCardImage)
            }
            octoprintClient.uploadFileToSDCard(filename: url.lastPathComponent, fileContent: fileData, callback: callback)
        }
    }

    fileprivate func selectFileToUpload() {
        if let _ = cloudFilesManager.containerUrl {
            let picker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .open)
            picker.delegate = self
            picker.modalPresentationStyle = .fullScreen
            present(picker, animated: false, completion: nil)
        } else {
            showAlert(NSLocalizedString("Warning", comment: ""), message: NSLocalizedString("Enable iCloud under iOS Settings to use this feature", comment: ""), done: nil)
        }
    }

    fileprivate func animateUploading(image: UIImageView) {
        // Make label visible
        image.isHidden = false
        // Start animating the label
        UIView.animate(withDuration: 0.7, delay: 0.5, options: [.repeat, .autoreverse], animations: {
            image.alpha = 0
        }, completion: nil)
    }

    fileprivate func showAlert(_ title: String, message: String, done: (() -> Void)?) {
        UIUtils.showAlert(presenter: self, title: title, message: message, done: done)
    }
}
