import UIKit

class CamerasViewController: UIViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {

    @IBOutlet weak var pageControl: UIPageControl!
    
    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()

    var infoGesturesAvailable: Bool = false // Flag that indicates if page wants to instruct user that gestures are available for full screen and zoom in/out
    
    // The UIPageViewController
    private var pageContainer: UIPageViewController!

    private var orderedViewControllers: Array<CameraEmbeddedViewController> = Array()
    // Track the current index
    private var currentIndex: Int? // No camera has been selected by the app or the user. This means that we need to indicate which camera to display
    private var pendingIndex: Int?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Create the page container
        pageContainer = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
        pageContainer.delegate = self
        pageContainer.dataSource = self

        // Add it to the view
        view.addSubview(pageContainer.view)

        // Configure our custom pageControl
        view.bringSubview(toFront: pageControl)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        updateViewControllersForPrinter(cameraChanged: false)
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

    func cameraOrientation() -> UIImageOrientation? {
        if let index = currentIndex {
            return orderedViewControllers[index].cameraOrientation
        }
        return nil
    }

    // MARK: - Notifications

    func printerSelectedChanged() {
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
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if completed {
            currentIndex = pendingIndex
            if let index = currentIndex {
                pageControl.currentPage = index
            }
        }
    }

    
    // MARK: - Private functions
    
    fileprivate func updateViewControllersForPrinter(cameraChanged: Bool) {
        var newViewControllers: Array<CameraEmbeddedViewController> = Array()
        if let printer = printerManager.getDefaultPrinter() {
            if let camerasURLs = printer.cameras {
                // MultiCam plugin is installed so show all cameras
                var index = 0
                for url in camerasURLs {
                    var cameraOrientation: UIImageOrientation
                    var cameraURL: String
                    
                    if url == "/webcam/?action=stream" {
                        cameraURL = printer.hostname + url
                        cameraOrientation = UIImageOrientation(rawValue: Int(printer.cameraOrientation))!
                    } else {
                        cameraURL = url
                        cameraOrientation = UIImageOrientation.up // MultiCam has no information about orientation of extra cameras so assume "normal" position - no flips
                    }
                    
                    newViewControllers.append(newEmbeddedCameraViewController(index: index, url: cameraURL, cameraOrientation: cameraOrientation))
                    index = index + 1
                }
            }
            if newViewControllers.isEmpty {
                // MultiCam plugin is not installed so just show default camera
                let cameraURL = printer.hostname + "/webcam/?action=stream"
                let cameraOrientation = UIImageOrientation(rawValue: Int(printer.cameraOrientation))!
                newViewControllers.append(newEmbeddedCameraViewController(index: 0, url: cameraURL, cameraOrientation: cameraOrientation))
            }
            orderedViewControllers = newViewControllers
        } else {
            orderedViewControllers = newViewControllers
        }
        
        pageControl.isHidden = orderedViewControllers.count < 2
        pageContainer.view.isUserInteractionEnabled = !pageControl.isHidden
        
        pageControl.numberOfPages = orderedViewControllers.count
        // Try preserving existing selected camera, if none then indicate which is first view controller.
        // If selection is bigger than existing cameras (since they were removed from server) then go to first one
        if currentIndex == nil || currentIndex! >= orderedViewControllers.count {
            if let firstViewController = orderedViewControllers.first {
                pageContainer.setViewControllers([firstViewController],
                                                 direction: .forward,
                                                 animated: true,
                                                 completion: nil)
                pageControl.currentPage = 0
                currentIndex = 0
            }
        } else if cameraChanged {
            orderedViewControllers[currentIndex!].cameraSelectedChanged()
        }
    }

    fileprivate func newEmbeddedCameraViewController(index: Int, url: String, cameraOrientation: UIImageOrientation) -> CameraEmbeddedViewController {
        var controller: CameraEmbeddedViewController
        // See if we can reuse existing controller
        let existing: CameraEmbeddedViewController? = orderedViewControllers.count > index ? orderedViewControllers[index] : nil
        if let _ = existing {
            controller = existing!
        } else {
            // Let's create a new one
            controller = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "CameraEmbeddedViewController") as! CameraEmbeddedViewController
        }
        controller.cameraURL = url
        controller.cameraOrientation = cameraOrientation
        controller.infoGesturesAvailable = infoGesturesAvailable
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
}
