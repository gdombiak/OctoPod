import Foundation

protocol AppConfigurationDelegate: class {
    
    // Notification that app lock state (i.e. app is in read-only mode) has changed 
    func appLockChanged(locked: Bool)
}
