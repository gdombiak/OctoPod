import UIKit

class NavigationController: UINavigationController, OctoPrintSettingsDelegate, DefaultPrinterManagerDelegate {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    let defaultPrinterManager: DefaultPrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).defaultPrinterManager }()

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
        // Listen to changes to default printer
        defaultPrinterManager.delegates.append(self)

        let printer = printerManager.getDefaultPrinter()
        refreshForPrinterColors(color: printer?.color)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Stop listening to changes to OctoPrint Settings
        octoprintClient.remove(octoPrintSettingsDelegate: self)
        // Stop listening to changes to default printer
        defaultPrinterManager.remove(defaultPrinterManagerDelegate: self)
    }
    
    func refreshForPrinterColors(color: String?) {
        let theme = Theme.currentTheme()
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.backgroundColor = theme.navigationTopColor(octoPrintColor: color)
            navigationBar.standardAppearance = appearance;
            navigationBar.scrollEdgeAppearance = appearance
        } else {
            // Fallback on earlier versions
            navigationBar.barTintColor = theme.navigationTopColor(octoPrintColor: color)
        }
        navigationBar.tintColor = theme.navigationTintColor(octoPrintColor: color)
        navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: theme.navigationTitleColor(octoPrintColor: color)]
    }

    // MARK: - OctoPrintSettingsDelegate
    
    func octoPrintColorChanged(color: String) {
        DispatchQueue.main.async {
            self.refreshForPrinterColors(color: color)
        }
    }
    
    // MARK: - DefaultPrinterManagerDelegate
    
    func defaultPrinterChanged() {
        DispatchQueue.main.async {
            let printer = self.printerManager.getDefaultPrinter()
            self.refreshForPrinterColors(color: printer?.color)
        }
    }
}
