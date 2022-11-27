import UIKit

private let reuseIdentifier = "cameraGridCell"

class CamerasGridViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()

    var cameraEmbeddedViewControllers: Array<CameraEmbeddedViewController> = Array()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Add embedded VCs
        self.addEmbeddedCameraViewControllers()
        // Theme background color
        self.collectionView.backgroundColor = Theme.currentTheme().backgroundColor()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        // First call super so children receive events
        super.viewDidDisappear(animated)
        // Then remove embedded VCs
        self.deleteEmbeddedCameraViewControllers()
    }

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return cameraEmbeddedViewControllers.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! CameraGridViewCell
    
        // Add embedded VC as a child view and use the view of the embedded VC as the view of the cell
        let embeddedVC = cameraEmbeddedViewControllers[indexPath.row]
        self.addChild(embeddedVC)
        cell.hostedView = embeddedVC.view
    
        return cell
    }
    
    /// MARK: UICollectionViewDelegateFlowLayout
    
    /// Calculate height based on width that changes per orientation and device. This method is also called when rotating device
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {        
        let ratio = cameraEmbeddedViewControllers[indexPath.row].cameraRatio!
        let width: CGFloat
        let inSplitView = collectionView.frame.width < UIScreen.main.bounds.width
        if UIDevice.current.orientation == .portrait || UIDevice.current.orientation == .portraitUpsideDown  || inSplitView {
            // iPhone in vertical position
            width = collectionView.frame.width
        } else {
            // iPhone in horizontal position
            width = collectionView.frame.width / 2 - 10 // Substract for spacing
        }
        return CGSize(width: width, height: width * ratio)
    }
    
    /// MARK: Private functions
    
    fileprivate func addEmbeddedCameraViewControllers() {
        if let printer = printerManager.getDefaultPrinter() {
            if let cameras = printer.getMultiCameras() {
                // MultiCam plugin is installed so show all cameras
                var index = 0
                for multiCamera in cameras {
                    var cameraOrientation: UIImage.Orientation
                    var cameraURL: String
                    let url = multiCamera.cameraURL
                    let ratio = multiCamera.streamRatio == "16:9" ? CGFloat(0.5625) : CGFloat(0.75)

                    if url == printer.getStreamPath() {
                        // This is camera hosted by OctoPrint so respect orientation
                        cameraURL = CameraUtils.shared.absoluteURL(hostname: printer.hostname, streamUrl: url)
                        cameraOrientation = UIImage.Orientation(rawValue: Int(printer.cameraOrientation))!
                    } else {
                        if url.starts(with: "/") {
                            // Another camera hosted by OctoPrint so build absolute URL
                            cameraURL = CameraUtils.shared.absoluteURL(hostname: printer.hostname, streamUrl: url)
                        } else {
                            // Use absolute URL to render camera
                            cameraURL = url
                        }
                        // Respect orientation defined by MultiCamera plugin
                        cameraOrientation = UIImage.Orientation(rawValue: Int(multiCamera.cameraOrientation))!
                    }
                    
                    cameraEmbeddedViewControllers.append(newEmbeddedCameraViewController(printer: printer, index: index, cameraRatio: ratio, url: cameraURL, cameraOrientation: cameraOrientation))
                    index = index + 1
                }
            }
            if cameraEmbeddedViewControllers.isEmpty && !printer.hideCamera {
                // MultiCam plugin is not installed so just show default camera
                let cameraURL = CameraUtils.shared.absoluteURL(hostname: printer.hostname, streamUrl: printer.getStreamPath())
                let cameraOrientation = UIImage.Orientation(rawValue: Int(printer.cameraOrientation))!
                let ratio = printer.firstCameraAspectRatio16_9 ? CGFloat(0.5625) : CGFloat(0.75)
                cameraEmbeddedViewControllers.append(newEmbeddedCameraViewController(printer: printer, index: 0, cameraRatio: ratio, url: cameraURL, cameraOrientation: cameraOrientation))
            }
        }
    }
    
    fileprivate func deleteEmbeddedCameraViewControllers() {
        for cameraEmbeddedViewController in cameraEmbeddedViewControllers {
            cameraEmbeddedViewController.removeFromParent()
            // Ask object to destroy itself to break any cyclic reference that would cause a memory leak. We won't use this object again
            cameraEmbeddedViewController.destroy()
        }
        cameraEmbeddedViewControllers.removeAll()
    }
    
    fileprivate func newEmbeddedCameraViewController(printer: Printer, index: Int, cameraRatio: CGFloat, url: String, cameraOrientation: UIImage.Orientation) -> CameraEmbeddedViewController {
        var controller: CameraEmbeddedViewController
        let useHLS = CameraUtils.shared.isHLS(url: url)
        // See if this is a printer controlled via Obico
        let tsdPrinter = printer.getPrinterConnectionType() == .obico
        // Let's create a new one. Use one for HLS and another one for MJPEG
        controller = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: useHLS ? "CameraHLSEmbeddedViewController" : tsdPrinter ? "CameraTSDEmbeddedViewController" : "CameraMJPEGEmbeddedViewController") as! CameraEmbeddedViewController
        controller.cameraURL = url
        controller.cameraOrientation = cameraOrientation
        controller.infoGesturesAvailable = false
        controller.cameraTappedCallback = nil // Tap will be handled as cell selected
        controller.cameraViewDelegate = nil
        controller.cameraIndex = index
        controller.cameraRatio = cameraRatio
        controller.camerasViewController = nil
        controller.muteVideo = true
        return controller
    }
}
