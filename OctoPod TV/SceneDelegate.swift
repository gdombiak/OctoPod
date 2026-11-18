import Network
import SwiftUI
import UIKit
#if DEBUG
import CoreData
#endif

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private var networkMonitor: NWPathMonitor?
    private let networkMonitorQueue = DispatchQueue(label: "org.OctoPod.TV.network")
    private var networkWasAvailable: Bool?

    private var appDelegate: AppDelegate {
        UIApplication.shared.delegate as! AppDelegate
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let contentView = ContentView()
            .environment(\.managedObjectContext, appDelegate.persistentContainer.viewContext)
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: contentView)
        #if DEBUG
        if isTestingCountdownOverflow {
            window.rootViewController = makeCountdownTestController()
        }
        #endif
        self.window = window
        window.makeKeyAndVisible()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        #if DEBUG
        guard !isTestingCountdownOverflow else { return }
        #endif
        let appDelegate = self.appDelegate
        monitorNetworkChanges()
        appDelegate.cloudKitPrinterManager.start(nil)
        appDelegate.tvPrinterManager.resumeConnections()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        appDelegate.tvPrinterManager.suspendConnections()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        stopMonitoringNetwork()
        appDelegate.saveContext()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        stopMonitoringNetwork()
    }

    private func monitorNetworkChanges() {
        guard networkMonitor == nil else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self, weak monitor] path in
            let isAvailable = path.status == .satisfied
            DispatchQueue.main.async {
                guard let self, let monitor, self.networkMonitor === monitor else { return }
                let wasAvailable = self.networkWasAvailable
                self.networkWasAvailable = isAvailable
                if wasAvailable == false && isAvailable {
                    self.appDelegate.cloudKitPrinterManager.start(nil)
                }
            }
        }
        networkMonitor = monitor
        monitor.start(queue: networkMonitorQueue)
    }

    private func stopMonitoringNetwork() {
        networkMonitor?.cancel()
        networkMonitor = nil
        networkWasAvailable = nil
    }

    #if DEBUG
    private var isTestingCountdownOverflow: Bool {
        ProcessInfo.processInfo.arguments.contains("--test-countdown-overflow")
    }

    private func makeCountdownTestController() -> UIViewController {
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = appDelegate.persistentContainer.persistentStoreCoordinator
        let printerID = NSEntityDescription.insertNewObject(forEntityName: "Printer", into: context).objectID
        let service = ViewService(tvPrinterManager: appDelegate.tvPrinterManager)
        service.printing = true
        service.printingFile = "Test.gcode"
        service.timeToFilamentRows = (1...8).map { index in
            TimeToFilamentRow(
                id: String(index),
                label: "Filament change at independently configured G-code marker number \(index)",
                value: "12 min"
            )
        }
        return UIHostingController(rootView: NavigationView {
            DetailedView(printerID: printerID, name: "Test Printer")
                .environmentObject(service)
                .environmentObject(CameraService())
        })
    }
    #endif
}
