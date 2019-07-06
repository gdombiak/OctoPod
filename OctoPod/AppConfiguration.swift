import Foundation

class AppConfiguration: OctoPrintClientDelegate {
    
    private static let APP_LOCKED = "APP_CONFIGURATION_LOCKED"
    private static let APP_LOCKED_AUTHENTICATION = "APP_CONFIGURATION_LOCKED_AUTHENTICATION"
    private static let APP_AUTO_LOCK = "APP_CONFIGURATION_AUTO_LOCKED"
    private static let CONFIRMATION_ON_CONNECT = "APP_CONFIGURATION_CONF_ON_CONNECT"
    private static let CONFIRMATION_ON_DISCONNECT = "APP_CONFIGURATION_CONF_ON_DISCONNECT"
    private static let DISABLE_CERT_VALIDATION = "APP_CONFIGURATION_DISABLE_CERT_VALIDATION"
    private static let DISABLE_TEMP_CHART_ZOOM = "APP_CONFIGURATION_DISABLE_TEMP_CHART_ZOOM"

    var delegates: Array<AppConfigurationDelegate> = Array()

    init(octoprintClient: OctoPrintClient) {
        octoprintClient.appConfiguration = self
        // Listen to events coming from OctoPrintClient
        octoprintClient.delegates.append(self)
    }

    // MARK: - Delegates operations
    
    func remove(appConfigurationDelegate toRemove: AppConfigurationDelegate) {
        delegates.removeAll(where: { $0 === toRemove })
    }

    // MARK: - App locking
    
    /// Returns true if user needs to authenticate (using biometrics or passcode)
    /// to unlock the app (i.e. allow "write" operations)
    func appLockedRequiresAuthentication() -> Bool {
        let defaults = UserDefaults.standard
        if let requires = defaults.object(forKey: AppConfiguration.APP_LOCKED_AUTHENTICATION) as? Bool {
            return requires
        }
        // A value does not exist so default to true
        appLockedRequiresAuthentication(requires: true)
        return true
    }
    
    /// Sets whether the user needs to authenticate (using biometrics or passcode)
    /// to unlock the app (i.e. allow "write" operations) or not
    func appLockedRequiresAuthentication(requires: Bool) {
        let defaults = UserDefaults.standard
        return defaults.set(requires, forKey: AppConfiguration.APP_LOCKED_AUTHENTICATION)
    }

    /// Returns true if the app is in a locked state. This means that
    /// read-only operations are only allowed. Operations like changing
    /// print settings, printer settings, change running jobs, .etc
    /// are not available
    func appLocked() -> Bool {
        let defaults = UserDefaults.standard
        return defaults.bool(forKey: AppConfiguration.APP_LOCKED)
    }
    
    // Changes app locking state. When app is locked
    // read-only operations are only allowed. Operations like changing
    // print settings, printer settings, change running jobs, .etc
    // are not available
    func appLocked(locked: Bool) {
        if appLocked() == locked {
            // Do nothing
            return
        }
        let defaults = UserDefaults.standard
        defaults.set(locked, forKey: AppConfiguration.APP_LOCKED)
        // Notify listeners that status has changed
        for delegate in delegates {
            delegate.appLockChanged(locked: locked)
        }
    }

    /// Returns true if the app will automatically lock when active
    /// printer is running a print job
    func appAutoLock() -> Bool {
        let defaults = UserDefaults.standard
        return defaults.bool(forKey: AppConfiguration.APP_AUTO_LOCK)
    }
    
    /// Sets whether the app will automatically lock when active printer
    /// is running a print job
    func appAutoLock(autoLock: Bool) {
        let defaults = UserDefaults.standard
        return defaults.set(autoLock, forKey: AppConfiguration.APP_AUTO_LOCK)
    }
    
    // MARK: - Printer Connection Confirmation

    /// Prompt for confirmation when asking OctoPrint to connect to printer
    /// Off by default.
    /// Some users might want to turn this on to prevent resetting the printer when connecting
    func confirmationOnConnect() -> Bool {
        let defaults = UserDefaults.standard
        return defaults.bool(forKey: AppConfiguration.CONFIRMATION_ON_CONNECT)
    }
    
    /// Set if prompt for confirmation when asking OctoPrint to connect to printer is on/off
    /// Some users might want to turn this on to prevent resetting the printer when connecting
    func confirmationOnConnect(enable: Bool) {
        let defaults = UserDefaults.standard
        return defaults.set(enable, forKey: AppConfiguration.CONFIRMATION_ON_CONNECT)
    }

    /// Prompt for confirmation when asking OctoPrint to disconnect from printer
    /// On by default.
    func confirmationOnDisconnect() -> Bool {
        let defaults = UserDefaults.standard
        if let result = defaults.object(forKey: AppConfiguration.CONFIRMATION_ON_DISCONNECT) as? Bool {
            return result
        }
        // A value does not exist so default to true
        confirmationOnDisconnect(enable: true)
        return true
    }
    
    /// Set if prompt for confirmation when asking OctoPrint to disconnect from printer is on/off
    func confirmationOnDisconnect(enable: Bool) {
        let defaults = UserDefaults.standard
        return defaults.set(enable, forKey: AppConfiguration.CONFIRMATION_ON_DISCONNECT)
    }
    
    // MARK: - SSL Certificate Validation
    
    /// Returns true if SSL Certification validation is disabled. Not recommended
    /// to disable certificates validation but might be necessary for most people
    /// that run OctoPrint with self-signed certificates and still want to use HTTPS
    /// Enabled by default
    func certValidationDisabled() -> Bool {
        let defaults = UserDefaults.standard
        return defaults.bool(forKey: AppConfiguration.DISABLE_CERT_VALIDATION)
    }
    
    /// Sets whether SSL Certification validation is disabled or not. Not recommended
    /// to disable certificates validation but might be necessary for most people
    /// that run OctoPrint with self-signed certificates and still want to use HTTPS
    /// Enabled by default
    func certValidationDisabled(disable: Bool) {
        let defaults = UserDefaults.standard
        defaults.set(disable, forKey: AppConfiguration.DISABLE_CERT_VALIDATION)
        // Notify listeners that cert validation setting has changed
        for delegate in delegates {
            delegate.certValidationChanged(disabled: disable)
        }
    }
    
    // MARK: - Temp Chart
    
    /// Returns true if temp chart does not let users do zoom in/out
    /// Enabled by default
    func tempChartZoomDisabled() -> Bool {
        let defaults = UserDefaults.standard
        return defaults.bool(forKey: AppConfiguration.DISABLE_TEMP_CHART_ZOOM)
    }
    
    /// Sets whether temp chart will let users do zoom in/out
    /// Enabled by default
    func tempChartZoomDisabled(disable: Bool) {
        let defaults = UserDefaults.standard
        defaults.set(disable, forKey: AppConfiguration.DISABLE_TEMP_CHART_ZOOM)
    }
    
    // MARK: - OctoPrintClientDelegate
    
    func notificationAboutToConnectToServer() {
        if appAutoLock() {
            // Assume that new printer is not printing so unlock the app
            // Once connected to OctoPrint we will know if printer is printing
            // and app will be locked
            appLocked(locked: false)
        }
    }
    
    func printerStateUpdated(event: CurrentStateEvent) {
        // Check app configuration for auto-lock based on printing status
        if let completion = event.progressCompletion, appAutoLock() {
            let isPrinting = completion > 0 && completion < 100
            appLocked(locked: isPrinting)
        }
    }
    
    func handleConnectionError(error: Error?, response: HTTPURLResponse) {
        // Do nothing
    }
    
    func websocketConnected() {
        // Do nothing
    }
    
    func websocketConnectionFailed(error: Error) {
        // Do nothing
    }

}
