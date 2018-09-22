import Foundation

class AppConfiguration {
    
    private static let APP_LOCKED = "APP_CONFIGURATION_LOCKED"
    private static let APP_LOCKED_AUTHENTICATION = "APP_CONFIGURATION_LOCKED_AUTHENTICATION"
    private static let CONFIRMATION_ON_CONNECT = "APP_CONFIGURATION_CONF_ON_CONNECT"
    private static let CONFIRMATION_ON_DISCONNECT = "APP_CONFIGURATION_CONF_ON_DISCONNECT"

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

    // Prompt for confirmation when asking OctoPrint to connect to printer
    // Off by default.
    // Some users might want to turn this on to prevent resetting the printer when connecting
    func confirmationOnConnect() -> Bool {
        let defaults = UserDefaults.standard
        return defaults.bool(forKey: AppConfiguration.CONFIRMATION_ON_CONNECT)
    }
    
    // Set if prompt for confirmation when asking OctoPrint to connect to printer is on/off
    // Some users might want to turn this on to prevent resetting the printer when connecting
    func confirmationOnConnect(enable: Bool) {
        let defaults = UserDefaults.standard
        return defaults.set(enable, forKey: AppConfiguration.CONFIRMATION_ON_CONNECT)
    }

    // Prompt for confirmation when asking OctoPrint to disconnect from printer
    // On by default.
    func confirmationOnDisconnect() -> Bool {
        let defaults = UserDefaults.standard
        if let result = defaults.object(forKey: AppConfiguration.CONFIRMATION_ON_DISCONNECT) as? Bool {
            return result
        }
        // A value does not exist so default to true
        confirmationOnDisconnect(enable: true)
        return true
    }
    
    // Set if prompt for confirmation when asking OctoPrint to disconnect from printer is on/off
    func confirmationOnDisconnect(enable: Bool) {
        let defaults = UserDefaults.standard
        return defaults.set(enable, forKey: AppConfiguration.CONFIRMATION_ON_DISCONNECT)
    }
}
