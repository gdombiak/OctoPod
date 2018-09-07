import UIKit

class MoveViewController: UIViewController, OctoPrintSettingsDelegate {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()

    @IBOutlet weak var printerSubpanelHeightConstraint: NSLayoutConstraint!
    
    var camerasViewController: CamerasViewController?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Keep track of children controllers
        trackChildrenControllers()        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if let printer = printerManager.getDefaultPrinter() {
            // Update window title to Camera name
            navigationItem.title = printer.name

            // Update layout depending on camera orientation
            updateForCameraOrientation(orientation: UIImageOrientation(rawValue: Int(printer.cameraOrientation))!)

            // Listen to changes to OctoPrint Settings in case the camera orientation has changed
            octoprintClient.octoPrintSettingsDelegates.append(self)
        } else {
            navigationItem.title = "Move"
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // Stop listening to changes to OctoPrint Settings
        octoprintClient.remove(octoPrintSettingsDelegate: self)
    }

    // MARK: - OctoPrintSettingsDelegate
    
    func sdSupportChanged(sdSupport: Bool) {
        // Do nothing
    }
    
    func cameraOrientationChanged(newOrientation: UIImageOrientation) {
        DispatchQueue.main.async {
            self.updateForCameraOrientation(orientation: newOrientation)
        }
    }
    
    // Notification that a new camera has been added or removed. We rely on MultiCam
    // plugin to be installed on OctoPrint so there is no need to re-enter this information
    // URL to cameras is returned in /api/settings under plugins->multicam
    func camerasChanged(camerasURLs: Array<String>) {
        camerasViewController?.camerasChanged(camerasURLs: camerasURLs)
    }

    // React when device orientation changes
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        if let printer = printerManager.getDefaultPrinter() {
            // Update layout depending on camera orientation
            updateForCameraOrientation(orientation: UIImageOrientation(rawValue: Int(printer.cameraOrientation))!, screenHeight: size.height)
        }
    }
    
    // MARK: - Private functions
    
    // We are using Container Views so this is how we keep a reference to the contained view controllers
    fileprivate func trackChildrenControllers() {
        guard let camerasChild = childViewControllers.first as? CamerasViewController else {
            fatalError("Check storyboard for missing CamerasViewController")
        }
        camerasViewController = camerasChild
    }
    
    fileprivate func updateForCameraOrientation(orientation: UIImageOrientation, screenHeight: CGFloat = UIScreen.main.bounds.height) {
        if self.printerSubpanelHeightConstraint == nil {
            // Do nothing since view never rendered
            return
        }
        if orientation == UIImageOrientation.left || orientation == UIImageOrientation.leftMirrored || orientation == UIImageOrientation.rightMirrored || orientation == UIImageOrientation.right {
            self.printerSubpanelHeightConstraint.constant = 280
        } else {
            let devicePortrait = UIDevice.current.orientation.isPortrait
            if devicePortrait {
                if screenHeight <= 667 {
                    // iPhone * (smaller models)
                    self.printerSubpanelHeightConstraint.constant = 273
                } else if screenHeight == 736 {
                    // iPhone 7/8 Plus
                    self.printerSubpanelHeightConstraint.constant = 313
                } else if screenHeight == 812 {
                    // iPhone X
                    self.printerSubpanelHeightConstraint.constant = 360
                } else if screenHeight == 1024 {
                    // iPad (9.7-inch)
                    self.printerSubpanelHeightConstraint.constant = 333
                } else if screenHeight == 1112 {
                    // iPad (10.5-inch)
                    self.printerSubpanelHeightConstraint.constant = 373
                } else if screenHeight >= 1366 {
                    // iPad (12.9-inch)
                    self.printerSubpanelHeightConstraint.constant = 483
                } else {
                    // Unknown device so use default value
                    self.printerSubpanelHeightConstraint.constant = 310
                }
            } else {
                if screenHeight <= 414 {
                    // iPhone * (smaller models)
                    // iPhone 7/8 Plus
                    // iPhone X
                    self.printerSubpanelHeightConstraint.constant = 330
                } else {
                    // iPads
                    self.printerSubpanelHeightConstraint.constant = 320
                }
            }
        }
    }
}
