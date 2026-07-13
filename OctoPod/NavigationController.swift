import UIKit

class NavigationController: UINavigationController, OctoPrintSettingsDelegate, DefaultPrinterManagerDelegate {

    lazy var printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    lazy var octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    lazy var defaultPrinterManager: DefaultPrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).defaultPrinterManager }()
    private var coreDataAppearanceDeferred = false
    private var coreDataAppearanceSetupActive = false

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(coreDataDidBecomeReady), name: AppDelegate.coreDataReadyNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard (UIApplication.shared.delegate as! AppDelegate).isCoreDataReady else {
            coreDataAppearanceDeferred = true
            return
        }
        configureForCoreDataReadyAppearance()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        coreDataAppearanceDeferred = false
        guard (UIApplication.shared.delegate as! AppDelegate).isCoreDataReady else {
            return
        }
        guard coreDataAppearanceSetupActive else {
            return
        }
        // Stop listening to changes to OctoPrint Settings
        octoprintClient.remove(octoPrintSettingsDelegate: self)
        // Stop listening to changes to default printer
        defaultPrinterManager.remove(defaultPrinterManagerDelegate: self)
        coreDataAppearanceSetupActive = false
    }

    @objc private func coreDataDidBecomeReady() {
        guard coreDataAppearanceDeferred else {
            return
        }
        coreDataAppearanceDeferred = false
        configureForCoreDataReadyAppearance()
    }

    private func configureForCoreDataReadyAppearance() {
        if !coreDataAppearanceSetupActive {
            // Listen to changes to OctoPrint Settings in case the camera orientation has changed
            octoprintClient.octoPrintSettingsDelegates.append(self)
            // Listen to changes to default printer
            defaultPrinterManager.delegates.append(self)
            coreDataAppearanceSetupActive = true
        }

        let printer = printerManager.getDefaultPrinter()
        refreshForPrinterColors(color: printer?.color)
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
