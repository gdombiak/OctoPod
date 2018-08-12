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
        updateForCameraOrientation(orientation: newOrientation)
    }
    
    // Notification that a new camera has been added or removed. We rely on MultiCam
    // plugin to be installed on OctoPrint so there is no need to re-enter this information
    // URL to cameras is returned in /api/settings under plugins->multicam
    func camerasChanged(camerasURLs: Array<String>) {
        camerasViewController?.camerasChanged(camerasURLs: camerasURLs)
    }

    // MARK: - Private functions
    
    // We are using Container Views so this is how we keep a reference to the contained view controllers
    fileprivate func trackChildrenControllers() {
        guard let camerasChild = childViewControllers.first as? CamerasViewController else {
            fatalError("Check storyboard for missing CamerasViewController")
        }
        camerasViewController = camerasChild
    }
    
    fileprivate func updateForCameraOrientation(orientation: UIImageOrientation) {
        if orientation == UIImageOrientation.left || orientation == UIImageOrientation.leftMirrored || orientation == UIImageOrientation.rightMirrored || orientation == UIImageOrientation.right {
            DispatchQueue.main.async {
                self.printerSubpanelHeightConstraint.constant = 280
            }
        } else {
            DispatchQueue.main.async {
                self.printerSubpanelHeightConstraint.constant = 310
            }
        }
    }
}
