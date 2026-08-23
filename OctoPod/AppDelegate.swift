import UIKit
import CoreData
import CloudKit
import UserNotifications
import Intents
import AVFoundation
import BackgroundTasks

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    static let coreDataReadyNotification = Notification.Name("AppDelegate.coreDataReady")
    static let backgroundRefreshTaskIdentifier = "org.OctoPod.OctoPod.refresh"

    // SceneDelegate owns the key window. UIApplicationDelegate still declares this
    // optional property, so keep a witness now that the deployment target is iOS 15+.
    var window: UIWindow?
    private let coreDataReadinessLock = NSLock()
    private var coreDataReady = false
    private var coreDataStartupAttempted = false
    // Fallback for a legacy UIApplicationDelegate URL callback received before
    // SceneDelegate has connected. The scene owns all other URL delivery.
    private var pendingOpenURL: URL?
    private weak var sceneDelegate: SceneDelegate?
    private var persistentStoreFailure = false
    private var appWideServicesStarted = false

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        registerBackgroundAppRefreshTask()
        // Cold-start URLs are delivered via SceneDelegate.connectionOptions.
        _ = persistentContainer
        return true
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
        receiveOpenURL(url)
    }

    // MARK: - Scene coordination

    /// The app delegate owns app-wide state; the connected scene owns its window and UI.
    /// OctoPod supports one scene configuration, so retaining the active delegate is enough
    /// to bridge legacy UIApplicationDelegate URL delivery without reintroducing window ownership.
    func connect(sceneDelegate: SceneDelegate) {
        self.sceneDelegate = sceneDelegate
        if persistentStoreFailure {
            sceneDelegate.presentPersistentStoreFailure()
            return
        }
        if isCoreDataReady {
            sceneDelegate.coreDataDidBecomeReady()
            deliverPendingOpenURLIfPossible()
        }
    }

    func disconnect(sceneDelegate: SceneDelegate) {
        if self.sceneDelegate === sceneDelegate {
            self.sceneDelegate = nil
        }
    }

    func sceneWillEnterForeground() {
        // CloudKit is app-wide, but a foreground scene is the appropriate lifecycle
        // signal to resume it. CloudKitPrinterManager coalesces overlapping starts.
        guard isCoreDataReady else {
            return
        }
        cloudKitPrinterManager.start(nil)
    }

    func receiveOpenURL(_ url: URL) -> Bool {
        guard let sceneDelegate = sceneDelegate else {
            if url.scheme == "octopod" {
                pendingOpenURL = url
                return true
            }
            return false
        }
        // A connected scene queues URLs until its Core Data-backed UI is ready.
        return sceneDelegate.openURL(url)
    }

    private func deliverPendingOpenURLIfPossible() {
        guard isCoreDataReady, let pendingURL = pendingOpenURL else {
            return
        }
        guard let sceneDelegate = sceneDelegate else {
            return
        }
        pendingOpenURL = nil
        _ = sceneDelegate.openURL(pendingURL)
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
        container.loadPersistentStores(completionHandler: { [weak self] (storeDescription, error) in
            if let error = error as NSError? {
                DispatchQueue.main.async {
                    let protectedDataAvailable = UIApplication.shared.isProtectedDataAvailable
                    NSLog("""
                    Core Data persistent store failed to load.
                    Store URL: \(storeDescription.url?.absoluteString ?? "(nil)")
                    Store type: \(storeDescription.type)
                    Error: \(error)
                    Domain: \(error.domain)
                    Code: \(error.code)
                    User info: \(error.userInfo)
                    Protected data available: \(protectedDataAvailable)
                    """)
                    self?.presentPersistentStoreFailure()
                }
            } else {
                DispatchQueue.main.async {
                    self?.finishCoreDataStartup()
                }
            }
        })
        return container
    }()

    var isCoreDataReady: Bool {
        coreDataReadinessLock.lock()
        defer { coreDataReadinessLock.unlock() }
        return coreDataReady
    }

    private func finishCoreDataStartup() {
        precondition(Thread.isMainThread)
        guard beginCoreDataStartup() else {
            return
        }
        guard moveCoreDataToSharedSpace() else {
            presentPersistentStoreFailure()
            return
        }

        coreDataReadinessLock.lock()
        coreDataReady = true
        coreDataReadinessLock.unlock()

        // Existing storyboard controllers may already be loaded but deferred their setup.
        NotificationCenter.default.post(name: AppDelegate.coreDataReadyNotification, object: self)
        startAppWideServicesIfNeeded()
        sceneDelegate?.coreDataDidBecomeReady()
        deliverPendingOpenURLIfPossible()
    }

    private func startAppWideServicesIfNeeded() {
        coreDataReadinessLock.lock()
        let shouldStart = !appWideServicesStarted
        appWideServicesStarted = true
        coreDataReadinessLock.unlock()

        guard shouldStart else {
            return
        }

        // Register to receive push notifications via APNs (CloudKit sends silent push notifications when records change)
        UIApplication.shared.registerForRemoteNotifications()

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .carPlay] , completionHandler: { (granted: Bool, error: Error?) -> Void in
            if !granted {
                NSLog("User did not grant to get notifications")
            }
            if let error = error {
                NSLog("Error asking to allow local notifications. Error: \(error)")
            }
        })

        self.cloudKitPrinterManager.start(nil)
        self.backgroundRefresher.start()
        self.liveActivitiesManager.start()
        scheduleBackgroundAppRefresh()

        INPreferences.requestSiriAuthorization{ (authStatus: INSiriAuthorizationStatus) in
            NSLog("Siri Authorization Status authorized: \(authStatus == INSiriAuthorizationStatus.authorized)")
        }
        IntentsDonations.initIntentsForAllPrinters(printerManager: printerManager!)
        UIApplication.shared.isIdleTimerDisabled = appConfiguration.turnOffIdleDisabled()
        watchSessionManager.start()
        try? AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.ambient,
                                                         mode: AVAudioSession.Mode.moviePlayback,
                                                         options: [.mixWithOthers])
    }

    private func beginCoreDataStartup() -> Bool {
        coreDataReadinessLock.lock()
        defer { coreDataReadinessLock.unlock() }
        guard !coreDataStartupAttempted else {
            return false
        }
        coreDataStartupAttempted = true
        return true
    }

    private func presentPersistentStoreFailure() {
        persistentStoreFailure = true
        sceneDelegate?.presentPersistentStoreFailure()
    }

    // Core Data database was moved from local storage to shared app group in release 2.1
    fileprivate func moveCoreDataToSharedSpace() -> Bool {
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

                let localStore = try psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: oldStoreURL, options: storeOptions)
                try psc.migratePersistentStore(localStore, to: newStoreURL, options: storeOptions, withType: NSSQLiteStoreType)
                
                // Delete old db files of local storage only after migration succeeds.
                SharedPersistentContainer.deleteStoreCoreDataFiles(directory: NSPersistentContainer.defaultDirectoryURL())
            } catch {
                NSLog("Error moving local Core Data store. Error: \(error)")
                // If removing the already-loaded app-group store succeeded but adding the
                // legacy store failed, restore the original coordinator state before failing.
                if psc.persistentStores.isEmpty {
                    do {
                        try psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: newStoreURL, options: storeOptions)
                    } catch {
                        NSLog("Error restoring app-group Core Data store after migration failure. Error: \(error)")
                    }
                }
                return false
            }
        } else if needDeleteOld {
            // Delete old files
            SharedPersistentContainer.deleteStoreCoreDataFiles(directory: NSPersistentContainer.defaultDirectoryURL())
        }
        return true
    }

    // MARK: - Core Data Saving support

    func saveContext () {
        guard isCoreDataReady else {
            return
        }
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
        NSLog("APNS registration failed: \(error)")
    }

    // MARK: - Remote notifications
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard isCoreDataReady else {
            completionHandler(.noData)
            return
        }
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
            if let printerID = dict["printer-id"] as? String {
                // Check if this is a pring job notification
                if let printerState = dict["printer-state"] as? String {
                    let progressCompletion = dict["printer-completion"] as? Double
                    let mediaURL = dict["media-url"] as? String
                    let test = dict["test"] as? Bool
                    let forceComplicationUpdate = dict["complication-update"] as? Bool
                    backgroundRefresher.refresh(printerID: printerID, printerState: printerState, progressCompletion: progressCompletion, mediaURL: mediaURL, test: test, forceComplicationUpdate: forceComplicationUpdate, completionHandler: completionHandler)
                } else if let bedEvent = dict["bed-event"] as? String {
                    // This is a bed event notification
                    let bedTemperature = dict["bed-temperature"] as! Double
                    let bedMinutes = dict["bed-minutes"] as? Int
                    bedNotificationsHandler.receivedNotification(printerID: printerID, event: bedEvent, temperature: bedTemperature, bedMinutes: bedMinutes, completionHandler: completionHandler)
                } else if let mmuEvent = dict["mmu-event"] as? String {
                    // This is an MMU event notification
                    mmuNotificationsHandler.receivedNotification(printerID: printerID, event: mmuEvent, completionHandler: completionHandler)
                } else {
                    // Unknown command. Execute completion handler
                    completionHandler(.noData)
                }
            } else {
                // No data was downloaded by this app
                completionHandler(.noData)
            }
        }
    }
    
    // MARK: - My extensions

    /// Applications with the "fetch" background mode may be given opportunities to fetch updated content in the background or when it is convenient for the system. This method will be called in these situations. You should call the fetchCompletionHandler as soon as you're finished performing that operation, so the system can accurately estimate its power and data cost.
    public func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard isCoreDataReady else {
            completionHandler(.noData)
            return
        }
        // Run background refresh
        backgroundRefresher.refresh(completionHandler: completionHandler)
    }

    /// Register the BGAppRefreshTask used as the iOS 13+ replacement for
    /// `setMinimumBackgroundFetchInterval`. Must run before launch finishes.
    private func registerBackgroundAppRefreshTask() {
        // Main queue: BackgroundRefresher.refresh reads Printer from the main
        // Core Data context. `using: nil` would run this on a background queue.
        BGTaskScheduler.shared.register(forTaskWithIdentifier: AppDelegate.backgroundRefreshTaskIdentifier, using: .main) { task in
            self.handleBackgroundAppRefresh(task: task as! BGAppRefreshTask)
        }
    }

    /// Ask the system to wake the app later so watch complications / local
    /// notifications can update when the OctoPod plugin is not installed.
    func scheduleBackgroundAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: AppDelegate.backgroundRefreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            NSLog("Could not schedule background app refresh: \(error)")
        }
    }

    private func handleBackgroundAppRefresh(task: BGAppRefreshTask) {
        scheduleBackgroundAppRefresh()
        guard isCoreDataReady else {
            task.setTaskCompleted(success: true)
            return
        }
        let lock = NSLock()
        var completed = false
        let complete = { (success: Bool) in
            lock.lock()
            defer { lock.unlock() }
            guard !completed else {
                return
            }
            completed = true
            task.setTaskCompleted(success: success)
        }
        task.expirationHandler = {
            complete(false)
        }
        backgroundRefresher.refresh { result in
            complete(result != .failed)
        }
    }

    // MARK: - My extensions

    lazy var printerManager: PrinterManager? = {
        let context = persistentContainer.viewContext
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        var printerManager = PrinterManager(managedObjectContext: context, persistentContainer: persistentContainer)
        return printerManager
    }()
    
    lazy var cloudKitPrinterManager: CloudKitPrinterManager = {
       return CloudKitPrinterManager(printerManager: self.printerManager!)
    }()

    lazy var octoprintClient: OctoPrintClient = {
        return OctoPrintClient(printerManager: self.printerManager!, appConfiguration: appConfiguration)
    }()

    lazy var cloudFilesManager: CloudFilesManager = {
        return CloudFilesManager(octoprintClient: self.octoprintClient)
    }()
    
    lazy var appConfiguration: AppConfiguration = {
        return AppConfiguration()
    }()
    
    lazy var watchSessionManager: WatchSessionManager = {
        return WatchSessionManager(printerManager: self.printerManager!, cloudKitPrinterManager: self.cloudKitPrinterManager, octoprintClient: self.octoprintClient)
    }()
    
    lazy var backgroundRefresher: BackgroundRefresher = {
        return BackgroundRefresher(octoPrintClient: self.octoprintClient, printerManager: self.printerManager!, watchSessionManager: self.watchSessionManager)
    }()
    
    lazy var notificationsManager: NotificationsManager = {
        return NotificationsManager(printerManager: self.printerManager!, octoprintClient: self.octoprintClient, defaultPrinterManager: self.defaultPrinterManager, mmuNotificationsHandler: self.mmuNotificationsHandler)
    }()
    
    lazy var bedNotificationsHandler: BedNotificationsHandler = {
        return BedNotificationsHandler(printerManager: self.printerManager!)
    }()
    
    lazy var mmuNotificationsHandler: MMUNotificationsHandler = {
        return MMUNotificationsHandler(printerManager: self.printerManager!)
    }()
    
    lazy var pluginUpdatesManager: PluginUpdatesManager = {
        return PluginUpdatesManager(printerManager: self.printerManager!, octoprintClient: self.octoprintClient, appConfiguration: self.appConfiguration)
    }()

    lazy var defaultPrinterManager: DefaultPrinterManager = {
        return DefaultPrinterManager(printerManager: self.printerManager!, octoprintClient: self.octoprintClient, watchSessionManager: self.watchSessionManager)
    }()
    
    lazy var liveActivitiesManager: LiveActivitiesManager = {
        return LiveActivitiesManager(printerManager: self.printerManager!, octoprintClient: self.octoprintClient)
    }()
}
