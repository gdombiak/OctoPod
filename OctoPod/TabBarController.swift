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
        let theme = Theme.currentTheme()
        tabBar.barTintColor = theme.tabBarColor()
        tabBar.tintColor = theme.tintColor()
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
