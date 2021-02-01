import Foundation

class AppConfiguration: ObservableObject {
    
    private static let APP_LOCKED = "APP_CONFIGURATION_LOCKED"
    private static let APP_AUTO_LOCK = "APP_CONFIGURATION_AUTO_LOCKED"
    private static let CONFIRMATION_PRINT = "APP_CONFIGURATION_CONF_PRINT"
    private static let CONFIRMATION_PAUSE = "APP_CONFIGURATION_CONF_PAUSE"
    private static let CONFIRMATION_RESUME = "APP_CONFIGURATION_CONF_RESUME"

    var delegates: Array<AppConfigurationDelegate> = Array()

    private let keyValStore = NSUbiquitousKeyValueStore()
    
    init() {
        // Listen to changes to NSUbiquitousKeyValueStore
        NotificationCenter.default.addObserver(self, selector: #selector(ubiquitousKeyValueStoreDidChange(notification:)), name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: keyValStore)
    }

    // MARK: - App locking
    
    /// Returns true if the app is in a locked state. This means that
    /// read-only operations are only allowed. Operations like changing
    /// print settings, printer settings, change running jobs, .etc
    /// are not available
    func appLocked() -> Bool {
        return keyValStore.bool(forKey: AppConfiguration.APP_LOCKED)
    }
    
    /// Returns true if the app will automatically lock when active
    /// printer is running a print job
    func appAutoLock() -> Bool {
        return keyValStore.bool(forKey: AppConfiguration.APP_AUTO_LOCK)
    }
    
    // MARK: - Print Job Confirmations

    /// Prompt for confirmation before starting new print
    /// Off by default.
    func confirmationStartPrint() -> Bool {
        return keyValStore.bool(forKey: AppConfiguration.CONFIRMATION_PRINT)
    }

    /// Prompt for confirmation before pausing print
    /// Off by default.
    func confirmationPausePrint() -> Bool {
        return keyValStore.bool(forKey: AppConfiguration.CONFIRMATION_PAUSE)
    }
    
    /// Prompt for confirmation before pausing print
    /// Off by default.
    func confirmationResumePrint() -> Bool {
        return keyValStore.bool(forKey: AppConfiguration.CONFIRMATION_RESUME)
    }
    
    // MARK: - SSL Certificate Validation
    
    /// Returns true if SSL Certification validation is disabled. Not recommended
    /// to disable certificates validation but might be necessary for most people
    /// that run OctoPrint with self-signed certificates and still want to use HTTPS
    /// Enabled by default
    func certValidationDisabled() -> Bool {
        return false
    }

    // MARK: - Listen to iCloud changes to NSUbiquitousKeyValueStore
    @objc public func ubiquitousKeyValueStoreDidChange(notification: NSNotification) {
        DispatchQueue.main.async {
            // Notify that some property changed
            self.objectWillChange.send()
        }
    }
}
