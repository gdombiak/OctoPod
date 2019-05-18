import UIKit
import CoreData
import CloudKit
import UserNotifications
import Intents

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Migrate Core Data database to shared group container (if needed)
        moveCoreDataToSharedSpace()
        
        // If no printers were defined then send to Setup window, if not go to first tab
        if let tabBarController = self.window!.rootViewController as? UITabBarController {
            tabBarController.selectedIndex = printerManager!.getPrinters().count == 0 ? 4 : 0
        }

        // Register to receive push notifications via APNs (CloudKit sends silent push notifications when records change)
        UIApplication.shared.registerForRemoteNotifications()

        // Requests authorization to interact with the user when local (and remote) notifications are delivered to the user's device
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .carPlay] , completionHandler: { (granted: Bool, error: Error?) -> Void in
            if !granted {
                NSLog("User did not grant to get notifications")
            }
            if let error = error {
                NSLog("Error asking to allow local notifications. Error: \(error)")
            }
        })

        // Start synchronizing with iCloud (if available)
        self.cloudKitPrinterManager.start()
        
        self.backgroundRefresher.start()
        
        // Enable background refresh and set minimum interval between fetches
        UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)

        // Request permission from the user to use Siri
        INPreferences.requestSiriAuthorization{ (authStatus: INSiriAuthorizationStatus) in
            NSLog("Siri Authorization Status authorized: \(authStatus == INSiriAuthorizationStatus.authorized)")
        }

        // Initialize Siri shortcuts for existing printers (this is a one time operation)
        IntentsDonations.initIntentsForAllPrinters(printerManager: printerManager!)

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.

        // Start synchronizing with iCloud (if available)
        self.cloudKitPrinterManager.start()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        watchSessionManager.start()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        self.saveContext()
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // Just open the app. No special logic for restored activity        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if let printerName = url.host?.removingPercentEncoding {
            // Switch to printer user clicked on when using Today's widget
            if let printer = printerManager?.getPrinterByName(name: printerName) {
                // Update stored printers
                printerManager?.changeToDefaultPrinter(printer)
                // Update Apple Watch with new selected printer
                watchSessionManager.pushPrinters()
                // Ask octoprintClient to connect to new OctoPrint server
                octoprintClient.connectToServer(printer: printer)
                // Notify listeners of this change (ugly hack: use watch session listeners. Should be refactored)
                for delegate in watchSessionManager.delegates {
                    delegate.defaultPrinterChanged()
                }

                // Go to main Panel window
                if let tabBarController = self.window!.rootViewController as? UITabBarController {
                    tabBarController.selectedIndex = 0
                }
                return true
            }
        }
        return false
    }

    // MARK: - Core Data stack

    lazy var persistentContainer: SharedPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = SharedPersistentContainer(name: "OctoPod")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    // Core Data database was moved from local storage to shared app group in release 2.1
    fileprivate func moveCoreDataToSharedSpace() {
        var storeOptions = [AnyHashable : Any]()
        storeOptions[NSMigratePersistentStoresAutomaticallyOption] = true
        storeOptions[NSInferMappingModelAutomaticallyOption] = true

        let psc = persistentContainer.persistentStoreCoordinator
        let newStoreURL: URL = SharedPersistentContainer.defaultDirectoryURL().appendingPathComponent("OctoPod.sqlite")
        let oldStoreURL = NSPersistentContainer.defaultDirectoryURL().appendingPathComponent("OctoPod.sqlite")
        
        var needMigrate = false
        var needDeleteOld = false
        
        if FileManager.default.fileExists(atPath: oldStoreURL.path) {
            needMigrate = true
        }
        if FileManager.default.fileExists(atPath: newStoreURL.path) && printerManager?.getPrinters().count ?? 0 > 0 {
            needMigrate = false
            if FileManager.default.fileExists(atPath: oldStoreURL.path) {
                needDeleteOld = true
            }
        }
        
        if needMigrate {
            do {
                // Remove existing store that we will add back after the import
                // This avoids the error of trying to have 2 duplicated stores
                if let existingStore = psc.persistentStores.last {
                    try psc.remove(existingStore)
                }
                
                try psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: oldStoreURL, options: storeOptions)
                if let localStore = psc.persistentStore(for: oldStoreURL) {
                    try psc.migratePersistentStore(localStore, to: newStoreURL, options: storeOptions, withType: NSSQLiteStoreType)
                    
                    // Delete old db files of local storage
                    SharedPersistentContainer.deleteStoreCoreDataFiles(directory: NSPersistentContainer.defaultDirectoryURL())
                }
            } catch {
                // Handle error
                print("Error moving local Core Data store. Error: \(error)")
            }
        } else if needDeleteOld {
            // Delete old files
            SharedPersistentContainer.deleteStoreCoreDataFiles(directory: NSPersistentContainer.defaultDirectoryURL())
        }
    }

    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

    // MARK: - Notifications of registeration for remote notifications
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.reduce("", {$0 + String(format: "%02X", $1)})
        notificationsManager.registerToken(token: token)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NSLog("APNs registration failed: \(error)")
    }

    // MARK: - Remote notifications
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let dict = userInfo as! [String: NSObject]
        // Check if notification is coming from CloudKit
        if let notification = CKNotification(fromRemoteNotificationDictionary: dict), notification.subscriptionID == cloudKitPrinterManager.SUBSCRIPTION_ID {
            cloudKitPrinterManager.pullChanges(completionHandler: {
                completionHandler(.newData)
            }, errorHandler: {
                completionHandler(.failed)
            })
        } else {
            // Check if notification is coming from OctoPrint's plugin
            if let printerID = dict["printer-id"] as? String, let printerState = dict["printer-state"] as? String {
                let progressCompletion = dict["printer-completion"] as? Double
                let mediaURL = dict["media-url"] as? String
                let test = dict["test"] as? Bool
                backgroundRefresher.refresh(printerID: printerID, printerState: printerState, progressCompletion: progressCompletion, mediaURL: mediaURL, test: test, completionHandler: completionHandler)
            } else {
                // No data was downloaded by this app
                completionHandler(.noData)
            }
        }
    }
    
    // MARK: - My extensions

    /// Applications with the "fetch" background mode may be given opportunities to fetch updated content in the background or when it is convenient for the system. This method will be called in these situations. You should call the fetchCompletionHandler as soon as you're finished performing that operation, so the system can accurately estimate its power and data cost.
    public func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Run background refresh
        backgroundRefresher.refresh(completionHandler: completionHandler)
    }

    // MARK: - My extensions

    lazy var printerManager: PrinterManager? = {
        let context = persistentContainer.viewContext
        var printerManager = PrinterManager()
        printerManager.managedObjectContext = context
        return printerManager
    }()
    
    lazy var cloudKitPrinterManager: CloudKitPrinterManager = {
       return CloudKitPrinterManager(printerManager: self.printerManager!)
    }()

    lazy var octoprintClient: OctoPrintClient = {
        return OctoPrintClient(printerManager: self.printerManager!)
    }()

    lazy var cloudFilesManager: CloudFilesManager = {
        return CloudFilesManager(octoprintClient: self.octoprintClient)
    }()
    
    lazy var appConfiguration: AppConfiguration = {
        return AppConfiguration(octoprintClient: self.octoprintClient)
    }()
    
    lazy var watchSessionManager: WatchSessionManager = {
        return WatchSessionManager(printerManager: self.printerManager!, cloudKitPrinterManager: self.cloudKitPrinterManager, octoprintClient: self.octoprintClient)
    }()
    
    lazy var backgroundRefresher: BackgroundRefresher = {
        return BackgroundRefresher(octoPrintClient: self.octoprintClient, printerManager: self.printerManager!, watchSessionManager: self.watchSessionManager)
    }()
    
    lazy var notificationsManager: NotificationsManager = {
        return NotificationsManager(printerManager: self.printerManager!, octoprintClient: self.octoprintClient, watchSessionManager: self.watchSessionManager)
    }()
}
