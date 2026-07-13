import UIKit

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var pendingOpenURL: URL?
    private var coreDataUIReady = false
    private var initialTabSelectionComplete = false

    private var appDelegate: AppDelegate {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            fatalError("OctoPod AppDelegate is unavailable")
        }
        return appDelegate
    }

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard scene is UIWindowScene else {
            return
        }

        // The scene manifest loads Main.storyboard. Keep that window hidden until its
        // Core Data-backed controllers have completed their deferred configuration.
        window?.isHidden = true
        pendingOpenURL = connectionOptions.urlContexts.first?.url
        appDelegate.connect(sceneDelegate: self)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        appDelegate.disconnect(sceneDelegate: self)
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        appDelegate.sceneWillEnterForeground()
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for context in URLContexts {
            _ = openURL(context.url)
        }
    }

    func coreDataDidBecomeReady() {
        guard !coreDataUIReady else {
            return
        }
        coreDataUIReady = true

        window?.makeKeyAndVisible()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            // Select a tab only after UIKit has attached the storyboard hierarchy to
            // the visible scene window, avoiding an unbalanced appearance transition.
            self.rootTabBarController?.selectedIndex = self.appDelegate.printerManager!.getPrinters().count == 0 ? 4 : 0
            self.initialTabSelectionComplete = true
            self.replayPendingOpenURLIfPossible()
        }
    }

    func presentPersistentStoreFailure() {
        let controller = UIViewController()
        controller.view.backgroundColor = .white
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = "OctoPod could not open its saved data. Your saved data was not deleted. Please restart the app or check device storage and access settings."
        label.translatesAutoresizingMaskIntoConstraints = false
        controller.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: controller.view.layoutMarginsGuide.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: controller.view.layoutMarginsGuide.trailingAnchor),
            label.centerYAnchor.constraint(equalTo: controller.view.centerYAnchor)
        ])
        window?.rootViewController = controller
        window?.makeKeyAndVisible()
    }

    func openURL(_ url: URL) -> Bool {
        guard url.scheme == "octopod" else {
            return false
        }
        guard coreDataUIReady, initialTabSelectionComplete else {
            pendingOpenURL = url
            return true
        }

        if url.absoluteString.starts(with: "octopod://x-coredata") {
            // iOS 16 sends with ':' and iOS 17 without it.
            let normalizedURL = url.absoluteString.replacingOccurrences(of: "octopod://x-coredata(:)*//",
                                                                          with: "x-coredata://",
                                                                          options: [.regularExpression])
            if let printerURL = URL(string: normalizedURL),
               let printer = appDelegate.printerManager?.getPrinterByObjectURL(url: printerURL) {
                selectPrinterAndPanel(printer)
                return true
            }
        } else if let printerName = url.host?.removingPercentEncoding {
            if let printer = appDelegate.printerManager?.getPrinterByName(name: printerName) {
                selectPrinterAndPanel(printer)
                return true
            } else if printerName == "goToDashboard" {
                // Preserve the activation delay used to let camera views render after
                // returning from a widget or Live Activity.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.showDashboard()
                }
                return true
            }
        }
        return false
    }

    private var rootTabBarController: UITabBarController? {
        window?.rootViewController as? UITabBarController
    }

    private func replayPendingOpenURLIfPossible() {
        guard let pendingOpenURL = pendingOpenURL else {
            return
        }
        self.pendingOpenURL = nil
        _ = openURL(pendingOpenURL)
    }

    private func selectPrinterAndPanel(_ printer: Printer) {
        // Wait for the scene to become active so camera rendering remains reliable.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else {
                return
            }
            self.appDelegate.defaultPrinterManager.changeToDefaultPrinter(printer: printer)
            self.rootTabBarController?.selectedIndex = 0
        }
    }

    private func showDashboard() {
        guard let tabBarController = rootTabBarController else {
            return
        }
        tabBarController.selectedIndex = 0
        if let navigationVC = tabBarController.selectedViewController as? NavigationController,
           let panelVC = navigationVC.topViewController as? PanelViewController {
            panelVC.performSegue(withIdentifier: "printers_dashboard", sender: self)
        }
    }
}
