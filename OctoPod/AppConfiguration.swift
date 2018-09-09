import Foundation

class AppConfiguration {
    
    private static let APP_LOCKED = "APP_CONFIGURATION_LOCKED"

    // MARK: - App locking
    
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
