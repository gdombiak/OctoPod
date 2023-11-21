import UIKit

class SubpanelsViewController: UIViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate, OctoPrintSettingsDelegate {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()

    @IBOutlet weak var pageControl: UIPageControl!
    
    // The UIPageViewController
    private var pageContainer: UIPageViewController!
    
    private var orderedViewControllers: Array<UIViewController> = Array()

    private var pendingIndex: Int?
    
    var subpanelsVCDelegate: SubpanelsVCDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Create the page container
        pageContainer = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
        pageContainer.dataSource = self
        pageContainer.delegate = self

        // Add UIPageViewController as child of this VC to preserve hierarchy. This will
        // fix any error of having detached view controllers
        addChild(pageContainer)

        // Add it to the view
        view.addSubview(pageContainer.view)
        
        // Configure our custom pageControl
        view.bringSubviewToFront(pageControl)

        // Reset subpanels
        orderedViewControllers = []
        let mainboard = UIStoryboard(name: "Main", bundle: nil)
        orderedViewControllers.append(mainboard.instantiateViewController(withIdentifier: "PrinterSubpanelViewController"))
        orderedViewControllers.append(mainboard.instantiateViewController(withIdentifier: "TempHistoryViewController"))
        orderedViewControllers.append(mainboard.instantiateViewController(withIdentifier: "CustomControlsViewController"))

        if let printer = printerManager.getDefaultPrinter() {
            if printer.psuControlInstalled {
                orderedViewControllers.append(createPSUControlVC(mainboard))
            }
            if let plugs = printer.getTPLinkSmartplugs() {
                if !plugs.isEmpty {
                    orderedViewControllers.append(createIPPlugVCBlock(plugin: Plugins.TP_LINK_SMARTPLUG)(mainboard))
                }
            }
            if let plugs = printer.getWemoPlugs(){
                if !plugs.isEmpty {
                    orderedViewControllers.append(createIPPlugVCBlock(plugin: Plugins.WEMO_SWITCH)(mainboard))
                }
            }
            if let plugs = printer.getDomoticzPlugs() {
                if !plugs.isEmpty {
                    orderedViewControllers.append(createIPPlugVCBlock(plugin: Plugins.DOMOTICZ)(mainboard))
                }
            }
            if let plugs = printer.getTasmotaPlugs() {
                if !plugs.isEmpty {
                    orderedViewControllers.append(createIPPlugVCBlock(plugin: Plugins.TASMOTA)(mainboard))
                }
            }
            if printer.cancelObjectInstalled {
                orderedViewControllers.append(createCancelObjectVC(mainboard))
            }
            if printer.octorelayInstalled {
                orderedViewControllers.append(createOctorelayVC(mainboard))
            }
            if printer.palette2Installed {
                orderedViewControllers.append(createPalette2VC(mainboard))
            }
            if !printer.getEnclosureOutputs().isEmpty {
                orderedViewControllers.append(createEnclosureVC(mainboard))
            }
            if printer.filamentManagerInstalled {
                orderedViewControllers.append(createFilamentManagerVC(mainboard))
            }
            if printer.spoolManagerInstalled {
                orderedViewControllers.append(createSpoolManagerVC(mainboard))
            }
        }
        orderedViewControllers.append(mainboard.instantiateViewController(withIdentifier: "SystemCommandsViewController"))

        // Set number of pages in the page control
        pageControl.numberOfPages = orderedViewControllers.count
        
        // Sort VCs and Render them
        sortAndRender()
        
        // Listen to changes to OctoPrint Settings
        octoprintClient.octoPrintSettingsDelegates.append(self)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // Theme the UI
        let theme = Theme.currentTheme()
        pageControl.pageIndicatorTintColor = theme.pageIndicatorTintColor()
        pageControl.currentPageIndicatorTintColor = theme.currentPageIndicatorTintColor()

    }

    /// Render first panel
    func renderFirstVC() {
        // Show first page as the initial page
        if let firstViewController = orderedViewControllers.first {
            pageContainer.setViewControllers([firstViewController],
                                             direction: .forward,
                                             animated: true,
                                             completion: nil)
            pageControl.currentPage = 0
        }
    }
    
    /// Returns the currently selected SubpanelViewController
    func currentSubpanelViewController() -> SubpanelViewController? {
        return orderedViewControllers[pageControl.currentPage] as? SubpanelViewController
    }
    
    // MARK: - Notifications
    
    func printerSelectedChanged() {
        // Add or remove subpanels depending on configuration
        let newObjectContext = printerManager.safePrivateContext()
        newObjectContext.perform {
            if let printer = self.printerManager.getDefaultPrinter(context: newObjectContext) {
                self.addRemoveVC(add: printer.psuControlInstalled, vcIdentifier: { $0.isMember(of: PSUControlViewController.self) }, createVC: self.createPSUControlVC)
                var addVC = false

                // Add VC for TPLinkSmartplug
                if let plugs = printer.getTPLinkSmartplugs() {
                    addVC = !plugs.isEmpty
                }
                self.addRemoveIPPlugPluginVC(plugin: Plugins.TP_LINK_SMARTPLUG, add: addVC)

                // Add VC for WemoSwitch
                if let plugs = printer.getWemoPlugs() {
                    addVC = !plugs.isEmpty
                }
                self.addRemoveIPPlugPluginVC(plugin: Plugins.WEMO_SWITCH, add: addVC)

                // Add VC for Domoticz
                if let plugs = printer.getDomoticzPlugs() {
                    addVC = !plugs.isEmpty
                }
                self.addRemoveIPPlugPluginVC(plugin: Plugins.DOMOTICZ, add: addVC)
                // Add VC for Tasmota
                if let plugs = printer.getTasmotaPlugs() {
                    addVC = !plugs.isEmpty
                }
                self.addRemoveIPPlugPluginVC(plugin: Plugins.TASMOTA, add: addVC)
                
                self.addRemoveVC(add: printer.cancelObjectInstalled, vcIdentifier: { $0.isMember(of: CancelObjectViewController.self) }, createVC: self.createCancelObjectVC)
                
                self.addRemoveVC(add: printer.octorelayInstalled, vcIdentifier: { $0.isMember(of: OctorelayViewController.self) }, createVC: self.createOctorelayVC)

                self.addRemoveVC(add: printer.palette2Installed, vcIdentifier: { $0.isMember(of: Palette2ViewController.self) }, createVC: self.createPalette2VC)

                self.addRemoveVC(add: !printer.getEnclosureOutputs().isEmpty, vcIdentifier: { $0.isMember(of: EnclosureViewController.self) }, createVC: self.createEnclosureVC)
                
                self.addRemoveVC(add: printer.filamentManagerInstalled, vcIdentifier: { $0.isMember(of: FilamentManagerViewController.self) }, createVC: self.createFilamentManagerVC)
                
                self.addRemoveVC(add: printer.spoolManagerInstalled, vcIdentifier: { $0.isMember(of: SpoolManagerViewController.self) }, createVC: self.createSpoolManagerVC)
            }
            // Notify subpanels of change of printer (OctoPrint)
            for case let subpanel as SubpanelViewController in self.orderedViewControllers {
                subpanel.printerSelectedChanged()
            }
        }
    }
    
    func currentStateUpdated(event: CurrentStateEvent) {
        for case let subpanel as SubpanelViewController in orderedViewControllers {
            subpanel.currentStateUpdated(event: event)
        }
    }
    
    /// Notification that visibility of tool0 temperature label has changed. Alert delegate
    func toolLabelVisibilityChanged() {
        subpanelsVCDelegate?.toolLabelVisibilityChanged()
    }
    
    /// Notification that temperature history has changed
    func tempHistoryChanged() {
        for case let subpanel as SubpanelViewController in orderedViewControllers {
            subpanel.tempHistoryChanged()
        }
    }
    
    // MARK: - UIPageViewControllerDataSource

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let viewControllerIndex = orderedViewControllers.firstIndex(of: viewController) else {
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
        guard let viewControllerIndex = orderedViewControllers.firstIndex(of: viewController) else {
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
        pendingIndex = orderedViewControllers.firstIndex(of: pendingViewControllers.first!)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if completed {
            if let index = pendingIndex {
                pageControl.currentPage = index
                // Notify listeners about new active VC
                subpanelsVCDelegate?.finishedTransitionSubpanel(index: index)
            }
        }
    }
    
    // MARK: - OctoPrintSettingsDelegate
    
    func psuControlAvailabilityChanged(installed: Bool) {
        addRemoveVC(add: installed, vcIdentifier: { $0.isMember(of: PSUControlViewController.self) }, createVC: createPSUControlVC)
    }
    
    func ipPlugsChanged(plugin: String, plugs: Array<IPPlug>) {
        addRemoveIPPlugPluginVC(plugin: plugin, add: !plugs.isEmpty)
    }
    
    func cancelObjectAvailabilityChanged(installed: Bool) {
        addRemoveVC(add: installed, vcIdentifier: { $0.isMember(of: CancelObjectViewController.self) }, createVC: createCancelObjectVC)
    }
    
    func octorelayAvailabilityChanged(installed: Bool) {
        addRemoveVC(add: installed, vcIdentifier: { $0.isMember(of: OctorelayViewController.self) }, createVC: createOctorelayVC)
    }
    
    func palette2Changed(installed: Bool) {
        addRemoveVC(add: installed, vcIdentifier: { $0.isMember(of: Palette2ViewController.self) }, createVC: createPalette2VC)
    }
    
    func palette2CanvasAvailabilityChanged(installed: Bool) {
        // Implement this later. Do nothing for now
    }
    
    func enclosureOutputsChanged() {
        if let printer = printerManager.getDefaultPrinter() {
            addRemoveVC(add: !printer.getEnclosureOutputs().isEmpty, vcIdentifier: { $0.isMember(of: EnclosureViewController.self) }, createVC: createEnclosureVC)
        } else {
            addRemoveVC(add: false, vcIdentifier: { $0.isMember(of: EnclosureViewController.self) }, createVC: createEnclosureVC)
        }
    }
    
    func filamentManagerAvailabilityChanged(installed: Bool) {
        addRemoveVC(add: installed, vcIdentifier: { $0.isMember(of: FilamentManagerViewController.self) }, createVC: createFilamentManagerVC)
    }
    
    func spoolManagerAvailabilityChanged(installed: Bool) {
        addRemoveVC(add: installed, vcIdentifier: { $0.isMember(of: SpoolManagerViewController.self) }, createVC: createSpoolManagerVC)
    }

    // MARK: - Private functions
    
    fileprivate func sortAndRender() {
        // Sort VCs since added VC might not need to go last
        self.orderedViewControllers.sort(by: { (vc1: UIViewController, vc2: UIViewController) -> Bool in
            (vc1 as! SubpanelViewController).position() < (vc2 as! SubpanelViewController).position()
        })
        
        renderFirstVC()
    }
    
    fileprivate func addRemoveVC(add: Bool, vcIdentifier: ((UIViewController) -> Bool), createVC: @escaping (UIStoryboard) -> UIViewController) {
        if add {
            // Make sure that we render requested VC
            if let _ = orderedViewControllers.first(where: vcIdentifier) {
                // Do nothing since we already have it installed
            } else {
                DispatchQueue.main.async {
                    let mainboard = UIStoryboard(name: "Main", bundle: nil)
                    self.orderedViewControllers.append(createVC(mainboard))
                    // Sort VCs and Render them
                    self.sortAndRender()
                    // Update number of pages in page control
                    self.pageControl.numberOfPages = self.orderedViewControllers.count
                }
            }
        } else {
            // Make sure that we are not rendering PSUControlViewController
            if let found = orderedViewControllers.first(where: vcIdentifier) {
                if let index = orderedViewControllers.firstIndex(of: found) {
                    orderedViewControllers.remove(at: index)
                    DispatchQueue.main.async {
                        // Force refresh of cached VCs
                        self.renderFirstVC()
                        // Check if we need to go to first page (only if deleted VC was active VC)
                        if self.pageControl.currentPage == index {
                            self.renderFirstVC()
                        }
                        // Update number of pages in page control
                        self.pageControl.numberOfPages = self.orderedViewControllers.count
                    }
                }
            }
        }
    }

    fileprivate func createPSUControlVC(_ mainboard: UIStoryboard) -> UIViewController {
        return mainboard.instantiateViewController(withIdentifier: "PSUControlViewController")
    }

    fileprivate func createIPPlugVCBlock(plugin: String) -> ((UIStoryboard) -> UIViewController) {
        return { (mainboard: UIStoryboard) -> UIViewController in
            if let vc = mainboard.instantiateViewController(withIdentifier: "IPPlugViewController") as? IPPlugViewController {
                vc.ipPlugPlugin = plugin
                return vc
            }
            fatalError("Failed to instantiate an IPPlugViewController")
        }
    }
    
    fileprivate func createPalette2VC(_ mainboard: UIStoryboard) -> UIViewController {
        return mainboard.instantiateViewController(withIdentifier: "Palette2ViewController")
    }
    
    fileprivate func addRemoveIPPlugPluginVC(plugin: String, add: Bool) {
        let vcIdentifier = { (vc: UIViewController) -> Bool in
            if let ipPlugVC = vc as? IPPlugViewController {
                return ipPlugVC.ipPlugPlugin == plugin
            }
            return false
        }
        addRemoveVC(add: add, vcIdentifier: vcIdentifier, createVC: createIPPlugVCBlock(plugin: plugin))
    }

    fileprivate func createCancelObjectVC(_ mainboard: UIStoryboard) -> UIViewController {
        return mainboard.instantiateViewController(withIdentifier: "CancelObjectViewController")
    }
    
    fileprivate func createOctorelayVC(_ mainboard: UIStoryboard) -> UIViewController {
        return mainboard.instantiateViewController(withIdentifier: "OctorelayViewController")
    }

    fileprivate func createEnclosureVC(_ mainboard: UIStoryboard) -> UIViewController {
        return mainboard.instantiateViewController(withIdentifier: "EnclosureViewController")
    }

    fileprivate func createFilamentManagerVC(_ mainboard: UIStoryboard) -> UIViewController {
        return mainboard.instantiateViewController(withIdentifier: "FilamentManagerViewController")
    }
    
    fileprivate func createSpoolManagerVC(_ mainboard: UIStoryboard) -> UIViewController {
        return mainboard.instantiateViewController(withIdentifier: "SpoolManagerViewController")
    }
}
