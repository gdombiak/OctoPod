import UIKit

class MoveViewController: UIViewController, OctoPrintSettingsDelegate {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()

    @IBOutlet weak var printerSubpanelHeightConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
    
    // MARK: - Private functions
    
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
