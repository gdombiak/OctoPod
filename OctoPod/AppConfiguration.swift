import Foundation

class AppConfiguration {
    
    private static let APP_LOCKED = "APP_CONFIGURATION_LOCKED"
    private static let APP_LOCKED_AUTHENTICATION = "APP_CONFIGURATION_LOCKED_AUTHENTICATION"

    // MARK: - App locking
    
    // Returns true if user needs to authenticate (using biometrics or passcode)
    // to unlock the app (i.e. allow "write" operations)
    func appLockedRequiresAuthentication() -> Bool {
        let defaults = UserDefaults.standard
        if let requires = defaults.object(forKey: AppConfiguration.APP_LOCKED_AUTHENTICATION) as? Bool {
            return requires
        }
        // A value does not exist so default to true
        appLockedRequiresAuthentication(requires: true)
        return true
    }
    
    // Sets whether the user needs to authenticate (using biometrics or passcode)
    // to unlock the app (i.e. allow "write" operations) or not
    func appLockedRequiresAuthentication(requires: Bool) {
        let defaults = UserDefaults.standard
        return defaults.set(requires, forKey: AppConfiguration.APP_LOCKED_AUTHENTICATION)
    }

    // Returns true if the app is in a locked state. This means that
    // read-only operations are only allowed. Operations like changing
    // print settings, printer settings, change running jobs, .etc
    // are not available
    func appLocked() -> Bool {
        let defaults = UserDefaults.standard
        return defaults.bool(forKey: AppConfiguration.APP_LOCKED)
    }
    
    // Changes app locking state. When app is locked
    // read-only operations are only allowed. Operations like changing
    // print settings, printer settings, change running jobs, .etc
    // are not available
    func appLocked(locked: Bool) {
        let defaults = UserDefaults.standard
        return defaults.set(locked, forKey: AppConfiguration.APP_LOCKED)
    }
    
}
