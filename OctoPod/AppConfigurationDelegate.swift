import Foundation

protocol AppConfigurationDelegate: AnyObject {
    
    // Notification that app lock state (i.e. app is in read-only mode) has changed 
    func appLockChanged(locked: Bool)
    
    // Notification that SSL certificate validation has changed (user enabled or disabled it)
    func certValidationChanged(disabled: Bool)
}

// Make everything optional so implementors of this protocol are not forced to implement everything
extension AppConfigurationDelegate {
    
    func appLockChanged(locked: Bool) {
    }
    
    func certValidationChanged(disabled: Bool) {
    }
}
