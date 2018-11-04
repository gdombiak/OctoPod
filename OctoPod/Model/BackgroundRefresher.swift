import Foundation
import UIKit
import UserNotifications

class BackgroundRefresher: OctoPrintClientDelegate {
    
    let octoprintClient: OctoPrintClient!
    let printerManager: PrinterManager!
    let watchSessionManager: WatchSessionManager!
    
    private var lastPrinterName: String?
    private var lastPrinterState: String?
    private var lastCompletion: Double?
    
    init(octoPrintClient: OctoPrintClient, printerManager: PrinterManager, watchSessionManager: WatchSessionManager) {
        self.octoprintClient = octoPrintClient
        self.printerManager = printerManager
        self.watchSessionManager = watchSessionManager
    }
    
    func start() {
        // This code below is more of a hack to aviod lazy initialization and make sure that this instance exists
        
        // Make sure we were not already listening
        octoprintClient.remove(octoPrintClientDelegate: self)
        // Listen to events coming from OctoPrintClient
        octoprintClient.delegates.append(self)
    }
    
    func refresh(completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if let printer = printerManager.getDefaultPrinter() {
            let restClient: OctoPrintRESTClient
            // Make sure that we have a REST Client to the default printer
            // If the app was not even in background then we need to create
            // a REST client, otherwise we will reuse what we already have
            if octoprintClient.octoPrintRESTClient.isConfigured() {
                restClient = octoprintClient.octoPrintRESTClient
            } else {
                // We need to create a new rest client to the default printer
                restClient = OctoPrintRESTClient()
                restClient.connectToServer(serverURL: printer.hostname, apiKey: printer.apiKey, username: printer.username, password: printer.password)
            }
            
            restClient.currentJobInfo { (result: NSObject?, error: Error?, response :HTTPURLResponse) in
                if let error = error {
                    NSLog("Error getting job info from background refresh. Error: \(error)")
                    completionHandler(.failed)
                } else if let result = result as? Dictionary<String, Any> {
                    var progressCompletion: Double?
                    if let state = result["state"] as? String {
                        if let progress = result["progress"] as? NSDictionary {
                            progressCompletion = progress["completion"] as? Double
                        }
                        self.pushComplicationUpdate(printerName: printer.name, state: state, completion: progressCompletion)
                        completionHandler(.newData)
                    } else {
                        completionHandler(.noData)
                    }
                } else {
                    if response.statusCode == 403 {
                        // Bad API Keys
                        NSLog("Error getting job info from background refresh. Incorrect API Key?")
                        completionHandler(.failed)
                    } else {
                        NSLog("Error getting job info from background refresh. Unkown HTTP code: \(response.statusCode)")
                        completionHandler(.failed)
                    }
                }
            }
        } else {
            // No printer selected
            completionHandler(.noData)
        }
    }
    
    // MARK: - OctoPrintClientDelegate
    
    // Notification that we are about to connect to OctoPrint server
    func notificationAboutToConnectToServer() {
        // Do nothing
    }
    
    // Notification that the current state of the printer has changed
    func printerStateUpdated(event: CurrentStateEvent) {
        if let printer = printerManager.getDefaultPrinter(), let state = event.state {
            pushComplicationUpdate(printerName: printer.name, state: state, completion: event.progressCompletion)
        }
    }
    
    // Notification that HTTP request failed (connection error, authentication error or unexpect http status code)
    func handleConnectionError(error: Error?, response: HTTPURLResponse) {
        // Do nothing
    }
    
    // Notification sent when websockets got connected
    func websocketConnected() {
        // Do nothing
    }
    
    // Notification sent when websockets got disconnected due to an error (or failed to connect)
    func websocketConnectionFailed(error: Error) {
        // Do nothing
    }
    
    // MARK: - Private functions
    
    fileprivate func pushComplicationUpdate(printerName: String, state: String, completion: Double?) {
        // Check if state has changed since last refresh
        if self.lastPrinterName != printerName || self.lastPrinterState != state {
            if let completion = completion {
                checkCompletedJobLocalNotification(printerName: printerName, state: state, completion: completion)
            }
            // Update last known state
            self.lastPrinterName = printerName
            self.lastPrinterState = state
            self.lastCompletion = completion
            // There is a budget of 50 pushes to the Apple Watch so let's only send relevant events
            var pushState = state
            if state == "Printing from SD" {
                pushState = "Printing"
            } else if state.starts(with: "Offline (Error:") {
                pushState = "Offline"
            }
            if pushState == "Offline" || pushState == "Operational" || pushState == "Printing" || pushState == "Paused" {
                // Update complication with received data
                self.watchSessionManager.updateComplications(printerName: printerName, printerState: pushState)
            }
        }
    }
    
    fileprivate func checkCompletedJobLocalNotification(printerName: String, state: String, completion: Double) {
        if self.lastPrinterName == printerName && self.lastPrinterState != "Operational" && (state == "Finishing" || state == "Operational") && lastCompletion != 100 && completion == 100 {
            // Create Local Notification's Content
            let content = UNMutableNotificationContent()
            content.title = printerName
            content.body = NSString.localizedUserNotificationString(forKey: "Print has finished", arguments: nil)
            
            // Create the request
            let uuidString = UUID().uuidString
            let request = UNNotificationRequest(identifier: uuidString, content: content, trigger: nil)
            
            // Schedule the request with the system.
            let notificationCenter = UNUserNotificationCenter.current()
            notificationCenter.add(request) { (error) in
                if let error = error {
                    NSLog("Error asking iOS to present local notification. Error: \(error)")
                }
            }
        }
    }
}
