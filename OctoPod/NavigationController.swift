import UIKit

class NavigationController: UINavigationController, OctoPrintSettingsDelegate, WatchSessionManagerDelegate {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    let watchSessionManager: WatchSessionManager = { return (UIApplication.shared.delegate as! AppDelegate).watchSessionManager }()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Listen to changes to OctoPrint Settings in case the camera orientation has changed
        octoprintClient.octoPrintSettingsDelegates.append(self)
        // Listen to changes coming from Apple Watch
        watchSessionManager.delegates.append(self)

        let printer = printerManager.getDefaultPrinter()
        refreshForPrinterColors(color: printer?.color)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Stop listening to changes to OctoPrint Settings
        octoprintClient.remove(octoPrintSettingsDelegate: self)
        // Stop listening to changes coming from Apple Watch
        watchSessionManager.remove(watchSessionManagerDelegate: self)
    }
    
    func refreshForPrinterColors(color: String?) {
        let theme = Theme.currentTheme()
        navigationBar.barTintColor = theme.navigationTopColor(octoPrintColor: color)
        navigationBar.tintColor = theme.navigationTintColor(octoPrintColor: color)
    }

    // MARK: - OctoPrintSettingsDelegate
    
    // Notification that OctoPrint's appearance has changed. A new color or its transparency has changed
    func octoPrintColorChanged(color: String) {
        DispatchQueue.main.async {
            self.refreshForPrinterColors(color: color)
        }
    }
    
    // MARK: - WatchSessionManagerDelegate
    
    // Notification that a new default printer has been selected from the Apple Watch app
    func defaultPrinterChanged() {
        DispatchQueue.main.async {
            let printer = self.printerManager.getDefaultPrinter()
            self.refreshForPrinterColors(color: printer?.color)
        }
    }
}
