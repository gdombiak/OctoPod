import UIKit

class PSUControlViewController: ThemedStaticUITableViewController, SubpanelViewController, OctoPrintPluginsDelegate {

    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()

    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var powerButton: UIButton!
    @IBOutlet weak var controlPowerLabel: UILabel!
    
    var isPSUOn: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Clean up message since we do not know PSU state
        controlPowerLabel.text = nil
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let theme = Theme.currentTheme()
        let labelColor = theme.labelColor()
        infoLabel.textColor = labelColor
        controlPowerLabel.textColor = labelColor
        
        // Listen to changes to OctoPrint Plugin messages
        octoprintClient.octoPrintPluginsDelegates.append(self)
        
        // Fetch status now and refresh UI. Websockets will eventually send updates
        fetchPSUStatus()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Stop listening to changes to OctoPrint Plugin messages
        octoprintClient.remove(octoPrintPluginsDelegate: self)
    }

    // MARK: - SubpanelViewController
    
    func printerSelectedChanged() {
        // Assume power is off to be safe
        isPSUOn = false
        // Fetch status now and refresh UI. Websockets will eventually send updates
        fetchPSUStatus()
    }
    
    // Notification that OctoPrint state has changed. This may include printer status information
    func currentStateUpdated(event: CurrentStateEvent) {
        // Do nothing
    }
    
    // MARK: - OctoPrintPluginsDelegate
    
    func pluginMessage(plugin: String, data: NSDictionary) {
        if plugin == "psucontrol" {
            if let on = data["isPSUOn"] as? Bool {
                isPSUOn = on
                refreshButton()
            }
        }
    }
    
    // Returns the position where this VC should appear in SubpanelsViewController's UIPageViewController
    // SubpanelsViewController's will sort subpanels by this number when being displayed
    func position() -> Int {
        return 2
    }
    
    // MARK: - Button action

    @IBAction func powerButtonPressed(_ sender: Any) {
        let changePower = {
            self.octoprintClient.turnPSU(on: !self.isPSUOn) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                if !requested {
                    self.showAlert("Warning", message: "Failed to request to turn power \(!self.isPSUOn ? "on" : "off")")
                }
            }}
        
        if isPSUOn {
            showConfirm(message: "You are about to turn off the PSU. Proceed?", yes: { (UIAlertAction) -> Void in
                changePower()
            }, no: { (UIAlertAction) -> Void in
                // Do nothing
            })
        } else {
            changePower()
        }
    }
    
    // MARK: - Private functions
    
    fileprivate func refreshButton() {
        if self.powerButton == nil {
            // UI is not initialized so do nothing
            return
        }
        DispatchQueue.main.async {
            self.powerButton.setImage(UIImage(named: self.isPSUOn ? "PSUPowerOff" : "PSUPowerOn"), for: .normal)
            self.controlPowerLabel.text = "Turn \(self.isPSUOn ? "Off" : "On")"
        }
    }

    fileprivate func fetchPSUStatus() {
        octoprintClient.getPSUState { (isOn: Bool?, error: Error?, response: HTTPURLResponse) in
            if let on = isOn {
                self.isPSUOn = on
                self.refreshButton()
            }
        }
    }
    
    fileprivate func showAlert(_ title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: { (UIAlertAction) -> Void in
            // Nothing to do here
        }))
        // We are not on the main thread so present dialog on main thread to prevent crashes
        DispatchQueue.main.async {
            self.present(alert, animated: true) { () -> Void in
                // Nothing to do here
            }
        }
    }

    fileprivate func showConfirm(message: String, yes: @escaping (UIAlertAction) -> Void, no: @escaping (UIAlertAction) -> Void) {
        let alert = UIAlertController(title: "Confirm", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: yes))
        // Use default style and not cancel style for NO so it appears on the right
        alert.addAction(UIAlertAction(title: "No", style: .default, handler: no))
        self.present(alert, animated: true) { () -> Void in
            // Nothing to do here
        }
    }
}
