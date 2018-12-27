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

    func refresh(printerID: String, printerState: String, progressCompletion: Double?, mediaURL: String?, completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if let idURL = URL(string: printerID), let printer = printerManager.getPrinterByObjectURL(url: idURL) {
            if let url = mediaURL, let fetchURL = URL(string: url) {
                let session = URLSession.shared
                let task = session.dataTask(with: fetchURL, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) in
                    if let imageData = data {
                        self.pushComplicationUpdate(printerName: printer.name, state: printerState, imageData: imageData, completion: progressCompletion)
                        completionHandler(.newData)
                    } else if let error = error {
                        NSLog("Error fetching image from provided URL: \(error)")

                        self.pushComplicationUpdate(printerName: printer.name, state: printerState, imageData: nil, completion: progressCompletion)
                        completionHandler(.newData)
                    }
                })
                task.resume()
            } else {
                self.pushComplicationUpdate(printerName: printer.name, state: printerState, imageData: nil, completion: progressCompletion)
                completionHandler(.newData)
            }
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
                        self.pushComplicationUpdate(printerName: printer.name, state: state, imageData: nil, completion: progressCompletion)
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
            pushComplicationUpdate(printerName: printer.name, state: state, imageData: nil, completion: event.progressCompletion)
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
    
    fileprivate func pushComplicationUpdate(printerName: String, state: String, imageData: Data?, completion: Double?) {
        // Check if state has changed since last refresh
        if self.lastPrinterName != printerName || self.lastPrinterState != state {
            if let completion = completion {
                checkCompletedJobLocalNotification(printerName: printerName, state: state, imageData: imageData, completion: completion)
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
    
    fileprivate func checkCompletedJobLocalNotification(printerName: String, state: String, imageData: Data?, completion: Double) {
        if self.lastPrinterName == printerName && self.lastPrinterState != "Operational" && (state == "Finishing" || state == "Operational") && lastCompletion != 100 && completion == 100 {
            // Create Local Notification's Content
            let content = UNMutableNotificationContent()
            content.title = printerName
            content.body = NSString.localizedUserNotificationString(forKey: "Print complete", arguments: nil)
            content.userInfo = ["printerName": printerName]
            
            if let imageData = imageData, let attachment = self.saveImageToDisk(data: imageData, options: nil) {
                content.attachments = [attachment]
            }

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
