import SwiftUI
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private var appDelegate: AppDelegate {
        UIApplication.shared.delegate as! AppDelegate
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let contentView = ContentView()
            .environment(\.managedObjectContext, appDelegate.persistentContainer.viewContext)
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: contentView)
        self.window = window
        window.makeKeyAndVisible()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        let appDelegate = self.appDelegate
        appDelegate.cloudKitPrinterManager.start {
            // Restore printer data from iCloud if tvOS has purged the local store.
            if let printerManager = appDelegate.printerManager, printerManager.getPrinters().isEmpty {
                appDelegate.cloudKitPrinterManager.resetLocalPrinters {} errorHandler: {}
            }
        }
        appDelegate.tvPrinterManager.resumeConnections()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        appDelegate.tvPrinterManager.suspendConnections()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        appDelegate.saveContext()
    }
}
