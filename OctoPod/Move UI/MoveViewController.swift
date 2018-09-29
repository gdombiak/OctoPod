import UIKit

class MoveViewController: UIViewController, OctoPrintSettingsDelegate {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()

    @IBOutlet weak var printerSubpanelHeightConstraint: NSLayoutConstraint!
    
    var camerasViewController: CamerasViewController?

    var screenHeight: CGFloat!
    var printerSubpanelHeightConstraintPortrait: CGFloat!
    var printerSubpanelHeightConstraintLandscape: CGFloat!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Keep track of children controllers
        trackChildrenControllers()        

        // Calculate constraint for subpanel
        calculatePrinterSubpanelHeightConstraints()
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
            updateForCameraOrientation(orientation: UIImage.Orientation(rawValue: Int(printer.cameraOrientation))!)

            // Listen to changes to OctoPrint Settings in case the camera orientation has changed
            octoprintClient.octoPrintSettingsDelegates.append(self)
        } else {
            navigationItem.title = NSLocalizedString("Move", comment: "")
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
    
    func cameraOrientationChanged(newOrientation: UIImage.Orientation) {
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
        super.viewWillTransition(to: size, with: coordinator)
        if let printer = printerManager.getDefaultPrinter() {
            // Update layout depending on camera orientation
            updateForCameraOrientation(orientation: UIImage.Orientation(rawValue: Int(printer.cameraOrientation))!, devicePortrait: size.height == screenHeight)
        }
    }
    
    // MARK: - Private functions
    
    // We are using Container Views so this is how we keep a reference to the contained view controllers
    fileprivate func trackChildrenControllers() {
        guard let camerasChild = children.first as? CamerasViewController else {
            fatalError("Check storyboard for missing CamerasViewController")
        }
        camerasViewController = camerasChild
    }
    
    fileprivate func updateForCameraOrientation(orientation: UIImage.Orientation, devicePortrait: Bool = UIApplication.shared.statusBarOrientation.isPortrait) {
        if printerSubpanelHeightConstraint == nil {
            // Do nothing since view never rendered
            return
        }
        if orientation == UIImage.Orientation.left || orientation == UIImage.Orientation.leftMirrored || orientation == UIImage.Orientation.rightMirrored || orientation == UIImage.Orientation.right {
            printerSubpanelHeightConstraint.constant = 280
        } else {
            printerSubpanelHeightConstraint.constant = devicePortrait ? printerSubpanelHeightConstraintPortrait! : printerSubpanelHeightConstraintLandscape!
        }
    }

    fileprivate func calculatePrinterSubpanelHeightConstraints() {
        let devicePortrait = UIApplication.shared.statusBarOrientation.isPortrait
        screenHeight = devicePortrait ? UIScreen.main.bounds.height : UIScreen.main.bounds.width
        if screenHeight <= 667 {
            // iPhone * (smaller models)
            printerSubpanelHeightConstraintPortrait = 273
            printerSubpanelHeightConstraintLandscape = 330
        } else if screenHeight == 736 {
            // iPhone 7/8 Plus
            printerSubpanelHeightConstraintPortrait = 313
            printerSubpanelHeightConstraintLandscape = 330
        } else if screenHeight == 812 {
            // iPhone X, Xs
            printerSubpanelHeightConstraintPortrait = 360
            printerSubpanelHeightConstraintLandscape = 330
        } else if screenHeight == 896 {
            // iPhone Xr, Xs Max
            printerSubpanelHeightConstraintPortrait = 413
            printerSubpanelHeightConstraintLandscape = 330
        } else if screenHeight == 1024 {
            // iPad (9.7-inch)
            printerSubpanelHeightConstraintPortrait = 333
            printerSubpanelHeightConstraintLandscape = 300
        } else if screenHeight == 1112 {
            // iPad (10.5-inch)
            printerSubpanelHeightConstraintPortrait = 373
            printerSubpanelHeightConstraintLandscape = 300
        } else if screenHeight >= 1366 {
            // iPad (12.9-inch)
            printerSubpanelHeightConstraintPortrait = 483
            printerSubpanelHeightConstraintLandscape = 300
        } else {
            // Unknown device so use default value
            printerSubpanelHeightConstraintPortrait = 310
            printerSubpanelHeightConstraintLandscape = 330
        }
    }    
}
