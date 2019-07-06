import Foundation
import UIKit
import UserNotifications

class BackgroundRefresher: OctoPrintClientDelegate, AbstractNotificationsHandler {
    
    let octoprintClient: OctoPrintClient!
    let printerManager: PrinterManager!
    let watchSessionManager: WatchSessionManager!
    
    private var lastKnownState: Dictionary<String, (state: String, completion: Double?)> = [:]
    
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

    func refresh(printerID: String, printerState: String, progressCompletion: Double?, mediaURL: String?, test: Bool?, completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if let idURL = URL(string: printerID), let printer = printerManager.getPrinterByObjectURL(url: idURL) {
            if test == true {
                self.checkCompletedJobLocalNotification(printerName: printer.name, state: printerState, mediaURL: mediaURL, completion: 100, test: true)
            } else {
                self.pushComplicationUpdate(printerName: printer.name, octopodPluginInstalled: printer.octopodPluginInstalled, state: printerState, mediaURL: mediaURL, completion: progressCompletion)
            }
            completionHandler(.newData)
        } else {
            // Unkown ID of printer
            completionHandler(.noData)
        }
    }

    func refresh(completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if let printer = printerManager.getDefaultPrinter() {
            // Check if OctoPrint instance has OctoPod plugin installed
            // If installed then no need to do a background refresh to know
            // if print job is done since plugin will send an immediate
            // notification when job is done/failed
            if printer.octopodPluginInstalled {
                completionHandler(.noData)
                return
            }
            
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
                        self.pushComplicationUpdate(printerName: printer.name, octopodPluginInstalled: printer.octopodPluginInstalled, state: state, mediaURL: nil, completion: progressCompletion)
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
    
    func notificationAboutToConnectToServer() {
        // Do nothing
    }
    
    func printerStateUpdated(event: CurrentStateEvent) {
        if let printer = printerManager.getDefaultPrinter(), let state = event.state {
            pushComplicationUpdate(printerName: printer.name, octopodPluginInstalled: printer.octopodPluginInstalled, state: state, mediaURL: nil, completion: event.progressCompletion)
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
    
    // MARK: - Private functions
    
    fileprivate func pushComplicationUpdate(printerName: String, octopodPluginInstalled: Bool, state: String, mediaURL: String?, completion: Double?) {
        // Check if state has changed since last refresh
        let lastState = self.lastKnownState[printerName]
        if lastState == nil || lastState?.state != state {
            if !octopodPluginInstalled, let completion = completion {
                // Send local notification if OctoPod plugin for OctoPrint is not installed
                checkCompletedJobLocalNotification(printerName: printerName, state: state, mediaURL: mediaURL, completion: completion, test: false)
            }
            // Update last known state
            self.lastKnownState[printerName] = (state, completion)
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
    
    fileprivate func checkCompletedJobLocalNotification(printerName: String, state: String, mediaURL: String?, completion: Double, test: Bool) {
        var sendLocalNotification = false
        if let lastState = self.lastKnownState[printerName] {
            sendLocalNotification = lastState.state != "Operational" && (state == "Finishing" || state == "Operational") && lastState.completion != 100 && completion == 100
        }
        if sendLocalNotification || test {
            // Create Local Notification's Content
            let content = createNotification(printerName: printerName)
            content.body = NSString.localizedUserNotificationString(forKey: "Print complete", arguments: nil)
            
            if let url = mediaURL, let fetchURL = URL(string: url) {
                do {
                    let imageData = try Data(contentsOf: fetchURL)
                    if let attachment = self.saveImageToDisk(data: imageData, options: nil) {
                        content.attachments = [attachment]
                    }
                } catch let error {
                    NSLog("Error fetching image from provided URL: \(error)")
                }
            }
            
            // Send local notification
            sendNotification(content: content)
        }
    }
    
    fileprivate func saveImageToDisk(data: Data, options: [NSObject : AnyObject]?) -> UNNotificationAttachment? {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString, isDirectory: true)
        let fileIdentifier = "image.jpg"
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            let fileURL = directory.appendingPathComponent(fileIdentifier)
            try data.write(to: fileURL, options: [])
            return  try UNNotificationAttachment(identifier: fileIdentifier, url: fileURL, options: options)
        } catch let error {
            NSLog("Error creating attachment from image: \(error)")
        }
        
        return nil
    }
}
