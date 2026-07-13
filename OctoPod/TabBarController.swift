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
}
