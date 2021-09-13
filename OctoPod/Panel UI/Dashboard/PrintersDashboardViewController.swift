import UIKit

private let reuseIdentifier = "PrinterCell"
private let cameraReuseIdentifier = "cameraGridCell"

class PrintersDashboardViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    var printers: Array<PrinterObserver> = []
    var panelViewController: PanelViewController?
    var cameraEmbeddedViewControllers: Array<CameraEmbeddedViewController> = Array()
    var displayCameras = false

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var toggleDisplayButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Disable estimated size for iOS 10 since it crashes on iPad and iPhone Plus
        let os = ProcessInfo().operatingSystemVersion
        if let layout = self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.estimatedItemSize = os.majorVersion == 10 ? CGSize(width: 0, height: 0) : UICollectionViewFlowLayout.automaticSize
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Theme background color
        let currentTheme = Theme.currentTheme()
        collectionView.backgroundColor = currentTheme.backgroundColor()
        self.view.backgroundColor = currentTheme.backgroundColor()
        self.toggleDisplayButton.backgroundColor = currentTheme.backgroundColor()

        printers = []
        for printer in printerManager.getPrinters() {
            // Only add printers that want to be displayed in dashboard
            if printer.includeInDashboard {
                let printerObserver = PrinterObserver(printersDashboardViewController: self, row: printers.count)
                printerObserver.connectToServer(printer: printer)
                printers.append(printerObserver)
            }
        }
        // Create embedded VCs (but will not be rendered yet)
        self.addEmbeddedCameraViewControllers()
        self.updateButtonIcon()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        for printerObserver in printers {
            printerObserver.disconnectFromServer()
        }
        // Remove embedded VCs
        self.deleteEmbeddedCameraViewControllers()
        printers = []
    }
    
    @IBAction func toggleCameraOrPanel(_ sender: Any) {
        displayCameras = !displayCameras
        self.updateButtonIcon()
        // Refresh table using reloadSections since reloadData() sometimes does not work due to an iOS bug?
        self.collectionView.reloadSections(IndexSet(integer: 0))
    }
    
    // MARK: UICollectionViewDataSource

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return displayCameras ? cameraEmbeddedViewControllers.count : printers.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if displayCameras {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cameraReuseIdentifier, for: indexPath) as! PrintersCameraGridViewCell

            // Set constraints for video view before adding video. This will let cell have correct size
            let size = videoViewSize(indexPath.row, collectionView)
            cell.cameraPlaceholderViewWidthAnchor.constant = size.width
            cell.cameraPlaceholderViewHeightAnchor.constant = size.height

            // Add embedded VC as a child view and use the view of the embedded VC as the view of the cell
            let embeddedVC = cameraEmbeddedViewControllers[indexPath.row]
            self.addChild(embeddedVC)
            cell.hostedView = embeddedVC.view
            // Display printer name at the top of the video in the cell
            if let cameraLabel = embeddedVC.cameraLabel {
                embeddedVC.topCameraLabel.text = cameraLabel
                embeddedVC.topCameraLabel.isHidden = false
            } else {
                embeddedVC.topCameraLabel.isHidden = true
            }
            if let printerObserver = printers[safeIndex: embeddedVC.cameraIndex] {
                updateVideoCellInfo(cell, printerObserver)
            }
            
            return cell

        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! PrinterViewCell
        
            if let printerObserver = printers[safeIndex: indexPath.row] {
                // Configure the cell
                cell.printerLabel.text = printerObserver.printerName
                cell.printerStatusLabel.text = printerObserver.printerStatus
                cell.progressLabel.text = printerObserver.progress
                cell.printTimeLabel.text = printerObserver.printTime
                cell.printTimeLeftLabel.text = printerObserver.printTimeLeft
                cell.printEstimatedCompletionLabel.text = printerObserver.printCompletion
                cell.layerLabel.text = printerObserver.layer
            }
        
            return cell
        }
    }

    // MARK: UICollectionViewDelegateFlowLayout
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if displayCameras {
            return videoCellSize(indexPath.row, collectionView)
        } else {
            let devicePortrait = UIApplication.shared.statusBarOrientation.isPortrait
            let portraitWidth = devicePortrait ? UIScreen.main.bounds.width : UIScreen.main.bounds.height
            if portraitWidth <= 320 {
                // Set cell width to fit in SE screen
                return CGSize(width: 265, height: 205)
            } else {
                // Set cell width to fit in any screen other than SE screen
                return CGSize(width: 300, height: 205)
            }
        }
    }
    
    // MARK: UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let printer = printerManager.getPrinterByName(name: printers[indexPath.row].printerName) {
            selectNewDefaultPrinter(printer: printer)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let theme = Theme.currentTheme()
        let textColor = theme.textColor()
        let labelColor = theme.labelColor()
        cell.backgroundColor = theme.cellBackgroundColor()

        if displayCameras {
            if let cell = cell as? PrintersCameraGridViewCell {
                cell.cameraPlaceholderView.backgroundColor = theme.cellBackgroundColor()
                cell.filenameLabel.textColor = textColor
                cell.progressLabel.textColor = textColor
                cell.etaLabel.textColor = textColor
            }
        } else {
            if let cell = cell as? PrinterViewCell {
                cell.printerLabel?.textColor = textColor
                cell.printedTextLabel?.textColor = labelColor
                cell.printTimeTextLabel?.textColor = labelColor
                cell.printTimeLeftTextLabel?.textColor = labelColor
                cell.printEstimatedCompletionTextLabel?.textColor = labelColor
                cell.printerStatusTextLabel?.textColor = labelColor
                cell.printerStatusLabel?.textColor = textColor
                
                cell.progressLabel?.textColor = textColor
                cell.printTimeLabel?.textColor = textColor
                cell.printTimeLeftLabel?.textColor = textColor
                cell.printEstimatedCompletionLabel?.textColor = textColor
                cell.layerTextLabel?.textColor = labelColor
                cell.layerLabel?.textColor = textColor
            }
        }
    }
        
    // MARK: Connection notifications
    
    func refreshItem(row: Int, printerObserver: PrinterObserver) {
        let indexPath: IndexPath = IndexPath(row: row, section: 0)
        if displayCameras {
            DispatchQueue.main.async {
                // Check that list of printers is still in sync with what is being displayed
                if let cell = self.collectionView.cellForItem(at: indexPath) as? PrintersCameraGridViewCell {
                    self.updateVideoCellInfo(cell, printerObserver)
                }
            }
        } else {
            DispatchQueue.main.async {
                // Check that list of printers is still in sync with what is being displayed
                if self.printers.count > row {
                    self.collectionView.reloadItems(at: [indexPath])
                }
            }
        }
    }

    // MARK: Private functions
    
    fileprivate func selectNewDefaultPrinter(printer: Printer) {
        // Notify of newly selected printer
        panelViewController?.changeDefaultPrinter(printer: printer)
        // Close this window and go back
        navigationController?.popViewController(animated: true)
    }
    
    fileprivate func updateButtonIcon() {
        let image = self.displayCameras ? UIImage(named: "Camera") : UIImage(named: "TextPanel")
        self.toggleDisplayButton.setImage(image, for: .normal)
    }
    
    fileprivate func videoCellSize(_ row: Int, _ collectionView: UICollectionView) -> CGSize {
        let videoSize = videoViewSize(row, collectionView)
        let cellHeight = videoSize.height + 14.5 + 2 + 24
        return CGSize(width: videoSize.width, height: cellHeight)
    }
    
    fileprivate func videoViewSize(_ row: Int, _ collectionView: UICollectionView) -> CGSize {
        let ratio = cameraEmbeddedViewControllers[row].cameraRatio!
        let width: CGFloat
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad has a lot of space so always fit 2 cameras per row
            width = collectionView.frame.width / 2 - 15 // Substract for spacing
        } else {
            if UIDevice.current.orientation == .portrait || UIDevice.current.orientation == .portraitUpsideDown {
                // iPhone in vertical position
                width = collectionView.frame.width - 20
            } else {
                // iPhone in horizontal position
                width = collectionView.frame.width / 2 - 15 // Substract for spacing
            }
        }
        let videoHeight = width * ratio
        return CGSize(width: width, height: videoHeight)
    }
    
    fileprivate func updateVideoCellInfo(_ cell: PrintersCameraGridViewCell, _ printerObserver: PrinterObserver) {
        cell.progressLabel.text = printerObserver.progress
        cell.etaLabel.text = printerObserver.printTimeLeft
        if let filename = printerObserver.jobFile {
            cell.filenameLabel.text = filename
        } else {
            cell.filenameLabel.text = ""
        }
    }
    
    fileprivate func addEmbeddedCameraViewControllers() {
        var printerIndex = 0
        for printer in printerManager.getPrinters() {
            if printer.includeInDashboard {
                if !printer.hideCamera {
                    // MultiCam plugin is not installed so just show default camera
                    let cameraURL = CameraUtils.shared.absoluteURL(hostname: printer.hostname, streamUrl: printer.getStreamPath())
                    let cameraOrientation = UIImage.Orientation(rawValue: Int(printer.cameraOrientation))!
                    let ratio = printer.firstCameraAspectRatio16_9 ? CGFloat(0.5625) : CGFloat(0.75)
                    let printerURL = printer.objectID.uriRepresentation().absoluteString
                    cameraEmbeddedViewControllers.append(newEmbeddedCameraViewController(printerURL: printerURL, index: printerIndex, label: printer.name, cameraRatio: ratio, url: cameraURL, cameraOrientation: cameraOrientation))
                }
                printerIndex += 1
            }
        }
    }
    
    fileprivate func deleteEmbeddedCameraViewControllers() {
        for cameraEmbeddedViewController in cameraEmbeddedViewControllers {
            cameraEmbeddedViewController.removeFromParent()
        }
        cameraEmbeddedViewControllers.removeAll()
    }
    
    fileprivate func newEmbeddedCameraViewController(printerURL: String, index: Int, label: String, cameraRatio: CGFloat, url: String, cameraOrientation: UIImage.Orientation) -> CameraEmbeddedViewController {
        var controller: CameraEmbeddedViewController
        let useHLS = CameraUtils.shared.isHLS(url: url)
        // Let's create a new one. Use one for HLS and another one for MJPEG
        controller = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: useHLS ? "CameraHLSEmbeddedViewController" : "CameraMJPEGEmbeddedViewController") as! CameraEmbeddedViewController
        controller.printerURL = printerURL
        controller.cameraLabel = label
        controller.cameraURL = url
        controller.cameraOrientation = cameraOrientation
        controller.infoGesturesAvailable = false
        controller.cameraTappedCallback = {(embeddedVC: CameraEmbeddedViewController) -> Void in
            if let url = embeddedVC.printerURL, let idURL = URL(string: url), let printer = self.printerManager.getPrinterByObjectURL(url: idURL) {
                DispatchQueue.main.async {
                    self.selectNewDefaultPrinter(printer: printer)
                }
            }
        }
        controller.cameraViewDelegate = nil
        controller.cameraIndex = index
        controller.cameraRatio = cameraRatio
        controller.camerasViewController = nil
        controller.muteVideo = true
        return controller
    }
}
