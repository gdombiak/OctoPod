import UIKit

class SubpanelsViewController: UIViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {

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
        
        let mainboard = UIStoryboard(name: "Main", bundle: nil)
        orderedViewControllers.append(mainboard.instantiateViewController(withIdentifier: "PrinterSubpanelViewController"))
        orderedViewControllers.append(mainboard.instantiateViewController(withIdentifier: "TempHistoryViewController"))

        // Set number of pages in the page control
        pageControl.numberOfPages = orderedViewControllers.count
        
        // Show first page as the initial page
        if let firstViewController = orderedViewControllers.first {
            pageContainer.setViewControllers([firstViewController],
                                             direction: .forward,
                                             animated: true,
                                             completion: nil)
            pageControl.currentPage = 0
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        let theme = Theme.currentTheme()
        pageControl.pageIndicatorTintColor = theme.pageIndicatorTintColor()
        pageControl.currentPageIndicatorTintColor = theme.currentPageIndicatorTintColor()
    }
    
    // MARK: - Notifications
    
    func printerSelectedChanged() {
        (orderedViewControllers.first as! PrinterSubpanelViewController).printerSelectedChanged()
        (orderedViewControllers.last as! TempHistoryViewController).printerSelectedChanged()
    }
    
    func currentStateUpdated(event: CurrentStateEvent) {
        (orderedViewControllers.first as! PrinterSubpanelViewController).currentStateUpdated(event: event)
        (orderedViewControllers.last as! TempHistoryViewController).currentStateUpdated(event: event)
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
}
