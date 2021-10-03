import UIKit
import AVKit

class CamerasViewController: UIViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate, AVPictureInPictureControllerDelegate {

    @IBOutlet weak var pageControl: UIPageControl!
    
    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()

    var infoGesturesAvailable: Bool = false // Flag that indicates if page wants to instruct user that gestures are available for full screen and zoom in/out
    var embeddedCameraTappedCallback: ((CameraEmbeddedViewController) -> Void)?
    var embeddedCameraDelegate: CameraViewDelegate?
    
    private var displayPrintStatus: Bool?

    // The UIPageViewController
    private var pageContainer: UIPageViewController!

    private var orderedViewControllers: Array<CameraEmbeddedViewController> = Array()
    // Track the current index
    private var currentIndex: Int? // No camera has been selected by the app or the user. This means that we need to indicate which camera to display
    private var pendingIndex: Int?

    var offerPIP = false
    var pictureInPictureController: AVPictureInPictureController?
    var userStartedPIP = false
    private var pipCameraIndex = 0
    private var pipClosedCallback: (() -> Void)?
    
    private var lastPrinterID: String?
    
    /// PrinterURL of pritner to show. If empty then show default printer
    var showPrinter: String?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Create the page container (seems that using .pageCurl avoids some assertion crash)
        pageContainer = UIPageViewController(transitionStyle: .pageCurl, navigationOrientation: .horizontal, options: nil)
        pageContainer.delegate = self
        pageContainer.dataSource = self

        // Add it to the view
        view.addSubview(pageContainer.view)

        // Configure our custom pageControl
        view.bringSubviewToFront(pageControl)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // Start listening to events when app will resign active state
        NotificationCenter.default.addObserver(self, selector: #selector(appwillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        
        if let printer = printerToShow() {
            let newPrinterID = printer.objectID.uriRepresentation().absoluteString
            let cameraChanged = newPrinterID != lastPrinterID
            lastPrinterID = newPrinterID
            updateViewControllersForPrinter(cameraChanged: cameraChanged)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // Stop listening to events when app will resign active state
        NotificationCenter.default.removeObserver(self)

        displayPrintStatus = nil
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Properties
    
    func cameraURL() -> String? {
        if let index = currentIndex {
            return orderedViewControllers[index].cameraURL
        }
        return nil
    }

    func cameraOrientation() -> UIImage.Orientation? {
        if let index = currentIndex {
            return orderedViewControllers[index].cameraOrientation
        }
        return nil
    }

    func displayPrintStatus(enabled: Bool) {
        if displayPrintStatus != enabled {
            if let index = currentIndex, orderedViewControllers.count > index {
                displayPrintStatus = enabled
                orderedViewControllers[index].displayPrintStatus(enabled: enabled)
            }
        }
    }
    
    // MARK: - Notifications

    func printerSelectedChanged() {
        self.displayPrintStatus = nil
        DispatchQueue.main.async {
            self.updateViewControllersForPrinter(cameraChanged: true)
        }
    }

    // Notification that path to camera hosted by OctoPrint has changed
    func cameraPathChanged(streamUrl: String) {
        DispatchQueue.main.async {
            self.updateViewControllersForPrinter(cameraChanged: true)
        }
    }

    // Notification that a new camera has been added or removed. We rely on MultiCam
    // plugin to be installed on OctoPrint so there is no need to re-enter this information
    // URL to cameras is returned in /api/settings under plugins->multicam
    func camerasChanged(camerasURLs: Array<String>) {
        DispatchQueue.main.async {
            self.updateViewControllersForPrinter(cameraChanged: true)
        }
    }
    
    func currentStateUpdated(event: CurrentStateEvent) {
        if let index = currentIndex, orderedViewControllers.count > index {
            orderedViewControllers[index].currentStateUpdated(event: event)
        }
    }
    
    // MARK: - UIPageViewControllerDataSource
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let viewControllerIndex = controllerIndex(targetViewController: viewController as! CameraEmbeddedViewController) else {
            return nil
        }
        
        let nextIndex = viewControllerIndex + 1
        let orderedViewControllersCount = orderedViewControllers.count
        
        // User is on the last view controller and swiped right to loop to
        // the first view controller.
        guard orderedViewControllersCount != nextIndex else {
            return orderedViewControllers.first
        }
        
        guard orderedViewControllersCount > nextIndex else {
            return nil
        }
        
        return orderedViewControllers[nextIndex]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let viewControllerIndex = controllerIndex(targetViewController: viewController as! CameraEmbeddedViewController) else {
            return nil
        }
        
        let previousIndex = viewControllerIndex - 1
        
        // User is on the first view controller and swiped left to loop to
        // the last view controller.
        guard previousIndex >= 0 else {
            return orderedViewControllers.last
        }
        
        guard orderedViewControllers.count > previousIndex else {
            return nil
        }
        
        return orderedViewControllers[previousIndex]
    }
    
    // MARK: - UIPageViewControllerDelegate
    
    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        pendingIndex = controllerIndex(targetViewController: pendingViewControllers.first! as! CameraEmbeddedViewController)
        embeddedCameraDelegate?.startTransitionNewPage()
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if completed {
            currentIndex = pendingIndex
            if let index = currentIndex {
                pageControl.currentPage = index
                displayPrintStatus = nil
            }
            embeddedCameraDelegate?.finishedTransitionNewPage()
        }
    }

    
    // MARK: - Private functions
    
    fileprivate func updateViewControllersForPrinter(cameraChanged: Bool) {
        if userStartedPIP {
            // Stop PIP
            self.stopPictureInPicture(pause: true)
        }

        if cameraChanged, let index = currentIndex, index < orderedViewControllers.count {
            // Stop rendering current printer's camera
            // This VC may or may not be reused for the newly selected printer so
            // we need to stop refreshing the camera
            let cameraVC = orderedViewControllers[index]
            cameraVC.stopRenderingPrinter()
        }
        // Create corresponding VCs according to the printer's cameras
        var newViewControllers: Array<CameraEmbeddedViewController> = Array()
        if let printer = printerToShow() {
            if let cameras = printer.getMultiCameras() {
                // MultiCam plugin is installed so show all cameras
                var index = 0
                for multiCamera in cameras {
                    var cameraOrientation: UIImage.Orientation
                    var cameraURL: String
                    let url = multiCamera.cameraURL

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
                    
                    newViewControllers.append(newEmbeddedCameraViewController(index: index, url: cameraURL, cameraOrientation: cameraOrientation))
                    index = index + 1
                }
            }
            if newViewControllers.isEmpty {
                // MultiCam plugin is not installed so just show default camera
                let cameraURL = CameraUtils.shared.absoluteURL(hostname: printer.hostname, streamUrl: printer.getStreamPath())
                let cameraOrientation = UIImage.Orientation(rawValue: Int(printer.cameraOrientation))!
                newViewControllers.append(newEmbeddedCameraViewController(index: 0, url: cameraURL, cameraOrientation: cameraOrientation))
            }
            orderedViewControllers = newViewControllers
        } else {
            orderedViewControllers = newViewControllers
        }
        
        pageControl.isHidden = orderedViewControllers.count < 2
        pageContainer.dataSource = pageControl.isHidden ? nil : self
        
        pageControl.numberOfPages = orderedViewControllers.count
        // Try preserving existing selected camera, if none then indicate which is first view controller.
        // If selection is bigger than existing cameras (since they were removed from server) then go to first one
        if currentIndex == nil || currentIndex! >= orderedViewControllers.count {
            renderFirstVC()
        } else if cameraChanged {
            let cameraVC = orderedViewControllers[currentIndex!]
            if let existingVCs = pageContainer.viewControllers {
                if existingVCs.contains(cameraVC) {
                    // Refresh valid VC
                    cameraVC.cameraSelectedChanged()
                } else {
                    // Reset VCs and start from first VS
                    renderFirstVC()
                }
            } else {
                renderFirstVC()
            }
        }
    }
    
    fileprivate func renderFirstVC() {
        if let firstViewController = orderedViewControllers.first {
            pageContainer.setViewControllers([firstViewController],
                                             direction: .forward,
                                             animated: true,
                                             completion: nil)
            pageControl.currentPage = 0
            currentIndex = 0
        }
    }
    
    fileprivate func newEmbeddedCameraViewController(index: Int, url: String, cameraOrientation: UIImage.Orientation) -> CameraEmbeddedViewController {
        var controller: CameraEmbeddedViewController
        // See if we can reuse existing controller
        let existing: CameraEmbeddedViewController? = orderedViewControllers.count > index ? orderedViewControllers[index] : nil
        let useHLS = CameraUtils.shared.isHLS(url: url)
        if useHLS, let _ = existing as? CameraHLSEmbeddedViewController {
            controller = existing!
        } else if !useHLS, let _ = existing as? CameraMJPEGEmbeddedViewController{
            controller = existing!
        } else {
            // Let's create a new one. Use one for HLS and another one for MJPEG
            controller = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: useHLS ? "CameraHLSEmbeddedViewController" : "CameraMJPEGEmbeddedViewController") as! CameraEmbeddedViewController
        }
        controller.cameraURL = url
        controller.cameraOrientation = cameraOrientation
        controller.infoGesturesAvailable = infoGesturesAvailable
        controller.cameraTappedCallback = embeddedCameraTappedCallback
        controller.cameraViewDelegate = embeddedCameraDelegate
        controller.cameraIndex = index
        controller.camerasViewController = self
        controller.printerURL = showPrinter
        return controller
    }
    
    fileprivate func controllerIndex(targetViewController: CameraEmbeddedViewController) -> Int? {
        var index = 0
        for controller in orderedViewControllers {
            if controller == targetViewController || controller.cameraURL == targetViewController.cameraURL {
                return index
            }
            index = index + 1
        }
        return nil
    }
    
    fileprivate func printerToShow() -> Printer? {
        if let printerURL = showPrinter, let idURL = URL(string: printerURL), let printer = printerManager.getPrinterByObjectURL(url: idURL) {
            return printer
        }
        return printerManager.getDefaultPrinter()
    }
    
    // MARK: - PIP support
    
    func initPictureInPictureController(playerLayer: AVPlayerLayer, pipClosedCallback: @escaping (() -> Void)) {
        self.pipClosedCallback = pipClosedCallback
        if userStartedPIP {
            // User is using PIP so we need to stop it and close it
            stopPictureInPicture(pause: false)
        }
        // Create a new controller, passing the reference to the AVPlayerLayer.
        pictureInPictureController = AVPictureInPictureController(playerLayer: playerLayer)
        pictureInPictureController?.delegate = self
    }
    
    func togglePictureInPictureMode() {
        if let pictureInPictureController = pictureInPictureController {
            if pictureInPictureController.isPictureInPictureActive {
                stopPictureInPicture(pause: false)
            } else {
                pictureInPictureController.startPictureInPicture()
                userStartedPIP = true
                pipCameraIndex = currentIndex!
            }
        }
    }
    
    func stopPictureInPicture(pause: Bool) {
        if pause {
            pictureInPictureController?.playerLayer.player?.pause()
        }
        pictureInPictureController?.stopPictureInPicture()
        userStartedPIP = false
    }
    
    @objc func appwillResignActive() {
        // If user did not start PIP then release pictureInPictureController
        // Otherwise iOS will start PIP automatically if user is in a window with
        // an HLS camera and user clicked on Home button or received a phone call
        // or any other event that will make the app no longer be active
        // Known issue: Double click on home and coming back to the app will no longer
        // have pipController so clicking on PIP button will do nothing
        if !userStartedPIP {
            pictureInPictureController = nil
        }
    }

    // MARK: - AVPictureInPictureControllerDelegate
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        pipClosedCallback?()
        if userStartedPIP {
            // User closed PIP rather than doing a pop-in
            if let tabBarController = (UIApplication.shared.delegate as! AppDelegate).window!.rootViewController as? UITabBarController {
                if tabBarController.selectedIndex == 0 && UIApplication.shared.applicationState == .active {
                    // We were already in Panel tab and app is in foregound so resume playing
                    pictureInPictureController.playerLayer.player?.play()
                }
            }
            userStartedPIP = false
        }
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        pipClosedCallback?()
        // We could be in any tab so go back to Panel tab AND camera started PIP
        if let tabBarController = (UIApplication.shared.delegate as! AppDelegate).window!.rootViewController as? UITabBarController {
            if tabBarController.selectedIndex != 0 {
                // Stop player since view will appear and will start a new player
                pictureInPictureController.playerLayer.player?.pause()
                // Go to Panel tab (we will already be on the proper camera since start PIP and then moving to another camera will stop PIP)
                tabBarController.selectedIndex = 0
            }
        }

        // Indicate that we are no longer in PIP.
        // User requested to pop-in. This event is fired before #didStop event. If user closed PIP
        // then this even is not fired and only #didStop is fired
        userStartedPIP = false

        completionHandler(true)
    }
}
