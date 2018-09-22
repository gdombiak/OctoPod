import UIKit

class SubpanelsViewController: UIViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate, OctoPrintSettingsDelegate {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()

    @IBOutlet weak var pageControl: UIPageControl!
    
    // The UIPageViewController
    private var pageContainer: UIPageViewController!
    
    private var orderedViewControllers: Array<UIViewController> = Array()

    private var pendingIndex: Int?

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
        }
        
        // Set number of pages in the page control
        pageControl.numberOfPages = orderedViewControllers.count
        
        renderFirstVC()
        
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

    // MARK: - Notifications
    
    func printerSelectedChanged() {
        // Add or remove subpanels depending on configuration
        if let printer = printerManager.getDefaultPrinter() {
            addRemoveVC(add: printer.psuControlInstalled, vcIdentifier: { $0.isMember(of: PSUControlViewController.self) }, createVC: createPSUControlVC)
            var addVC = false

            // Add VC for TPLinkSmartplug
            if let plugs = printer.getTPLinkSmartplugs() {
                addVC = !plugs.isEmpty
            }
            addRemoveIPPlugPluginVC(plugin: Plugins.TP_LINK_SMARTPLUG, add: addVC)

            // Add VC for WemoSwitch
            if let plugs = printer.getWemoPlugs() {
                addVC = !plugs.isEmpty
            }
            addRemoveIPPlugPluginVC(plugin: Plugins.WEMO_SWITCH, add: addVC)

            // Add VC for Domoticz
            if let plugs = printer.getDomoticzPlugs() {
                addVC = !plugs.isEmpty
            }
            addRemoveIPPlugPluginVC(plugin: Plugins.DOMOTICZ, add: addVC)
            // Add VC for Tasmota
            if let plugs = printer.getTasmotaPlugs() {
                addVC = !plugs.isEmpty
            }
            addRemoveIPPlugPluginVC(plugin: Plugins.TASMOTA, add: addVC)
        }
        // Notify subpanels of change of printer (OctoPrint)
        for case let subpanel as SubpanelViewController in orderedViewControllers {
            subpanel.printerSelectedChanged()
        }
    }
    
    func currentStateUpdated(event: CurrentStateEvent) {
        for case let subpanel as SubpanelViewController in orderedViewControllers {
            subpanel.currentStateUpdated(event: event)
        }
    }
    
    // MARK: - UIPageViewControllerDataSource

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let viewControllerIndex = orderedViewControllers.index(of: viewController) else {
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
        guard let viewControllerIndex = orderedViewControllers.index(of: viewController) else {
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
        pendingIndex = orderedViewControllers.index(of: pendingViewControllers.first!)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if completed {
            if let index = pendingIndex {
                pageControl.currentPage = index
            }
        }
    }
    
    // MARK: - OctoPrintSettingsDelegate
    
    func psuControlAvailabilityChanged(installed: Bool) {
        addRemoveVC(add: installed, vcIdentifier: { $0.isMember(of: PSUControlViewController.self) }, createVC: createPSUControlVC)
    }
    
    // Notification that an IP plug plugin has changed. Could be availability or settings
    func ipPlugsChanged(plugin: String, plugs: Array<Printer.IPPlug>) {
        addRemoveIPPlugPluginVC(plugin: plugin, add: !plugs.isEmpty)
    }

    // MARK: - Private functions
    
    fileprivate func renderFirstVC() {
        // Show first page as the initial page
        if let firstViewController = orderedViewControllers.first {
            pageContainer.setViewControllers([firstViewController],
                                             direction: .forward,
                                             animated: true,
                                             completion: nil)
            pageControl.currentPage = 0
        }
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
                    // Sort VCs since added VC might not need to go last
                    self.orderedViewControllers.sort(by: { (vc1: UIViewController, vc2: UIViewController) -> Bool in
                        (vc1 as! SubpanelViewController).position() < (vc2 as! SubpanelViewController).position()
                    })
                    // Force refresh of cached VCs
                    self.renderFirstVC()
                    // Update number of pages in page control
                    self.pageControl.numberOfPages = self.orderedViewControllers.count
                }
            }
        } else {
            // Make sure that we are not rendering PSUControlViewController
            if let found = orderedViewControllers.first(where: vcIdentifier) {
                if let index = orderedViewControllers.index(of: found) {
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
    
    fileprivate func addRemoveIPPlugPluginVC(plugin: String, add: Bool) {
        let vcIdentifier = { (vc: UIViewController) -> Bool in
            if let ipPlugVC = vc as? IPPlugViewController {
                return ipPlugVC.ipPlugPlugin == plugin
            }
            return false
        }
        addRemoveVC(add: add, vcIdentifier: vcIdentifier, createVC: createIPPlugVCBlock(plugin: plugin))
    }
}
