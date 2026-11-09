import UIKit

class TabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()

        if #available(iOS 18.0, *) {
            mode = .tabBar
            if UIDevice.current.userInterfaceIdiom == .pad {
                traitOverrides.horizontalSizeClass = .compact
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshAppearance()
    }

    func refreshAppearance() {
        ThemeUIUtils.applyInterfaceStyle(to: self)
        ThemeUIUtils.applyTheme(tabBar: tabBar)
        // Theme switches happen on the settings tab. The other tabs stay offscreen,
        // so recolor their bars now instead of waiting until the next layout.
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
              appDelegate.isCoreDataReady,
              let printerManager = appDelegate.printerManager else {
            return
        }
        let color = printerManager.getDefaultPrinter()?.color
        for case let navigationController as NavigationController in viewControllers ?? [] where navigationController.isViewLoaded {
            navigationController.refreshForPrinterColors(color: color)
        }
    }

    // The window scene consults the root tab controller, not the selected
    // child's top VC. Forward so PanelViewController can own fullscreen policy.
    override var shouldAutorotate: Bool {
        selectedViewController?.shouldAutorotate ?? true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        selectedViewController?.supportedInterfaceOrientations ?? super.supportedInterfaceOrientations
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        selectedViewController?.preferredInterfaceOrientationForPresentation ?? super.preferredInterfaceOrientationForPresentation
    }
}
