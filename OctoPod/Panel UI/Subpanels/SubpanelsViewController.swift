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
        addChildViewController(pageContainer)

        // Add it to the view
        view.addSubview(pageContainer.view)
        
        // Configure our custom pageControl
        view.bringSubview(toFront: pageControl)

        // Reset subpanels
        orderedViewControllers = []
        let mainboard = UIStoryboard(name: "Main", bundle: nil)
        orderedViewControllers.append(mainboard.instantiateViewController(withIdentifier: "PrinterSubpanelViewController"))
        orderedViewControllers.append(mainboard.instantiateViewController(withIdentifier: "TempHistoryViewController"))
        
        if let printer = printerManager.getDefaultPrinter() {
            if printer.psuControlInstalled {
                orderedViewControllers.append(createPSUControlVC(mainboard))
            }
            if let plugs = printer.getTPLinkSmartplugs() {
                if !plugs.isEmpty {
                    orderedViewControllers.append(createTPLinkSmartplugVC(mainboard))
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
        addRemoveVC(add: installed, vcType: PSUControlViewController.self, createVC: createPSUControlVC)
    }
    
    func tplinkSmartpluglChanged(plugs: Array<Printer.TPLinkSmartplug>) {
        addRemoveVC(add: !plugs.isEmpty, vcType: TPLinkSmartplugViewController.self, createVC: createTPLinkSmartplugVC)
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
    
    fileprivate func addRemoveVC<T: UIViewController>(add: Bool, vcType: T.Type, createVC: (UIStoryboard) -> UIViewController) {
        if add {
            // Make sure that we render requested VC
            if let _ = orderedViewControllers.first(where: { $0.isMember(of: vcType) }) {
                // Do nothing since we already have it installed
            } else {
                let mainboard = UIStoryboard(name: "Main", bundle: nil)
                orderedViewControllers.append(createVC(mainboard))
                DispatchQueue.main.async {
                    // Force refresh of cached VCs
                    self.pageContainer.dataSource = nil
                    self.pageContainer.dataSource = self
                    // Update number of pages in page control
                    self.pageControl.numberOfPages = self.orderedViewControllers.count
                }
            }
        } else {
            // Make sure that we are not rendering PSUControlViewController
            if let found = orderedViewControllers.first(where: { $0.isMember(of: vcType) }) {
                if let index = orderedViewControllers.index(of: found) {
                    orderedViewControllers.remove(at: index)
                    DispatchQueue.main.async {
                        // Force refresh of cached VCs
                        self.pageContainer.dataSource = nil
                        self.pageContainer.dataSource = self
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

    fileprivate func createTPLinkSmartplugVC(_ mainboard: UIStoryboard) -> UIViewController {
        return mainboard.instantiateViewController(withIdentifier: "TPLinkSmartplugViewController")
    }
}
