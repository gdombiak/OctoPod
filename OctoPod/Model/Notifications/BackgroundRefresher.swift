import Foundation
import UIKit
import UserNotifications
import WidgetKit

class BackgroundRefresher: OctoPrintClientDelegate, AbstractNotificationsHandler {
    
    let octoprintClient: OctoPrintClient!
    let printerManager: PrinterManager!
    let watchSessionManager: WatchSessionManager!
    
    private var lastKnownState: Dictionary<String, (state: String, completion: Double?)> = [:]
    private let accessQueue = DispatchQueue(label: "lastKnownStateAccess", attributes: .concurrent)
    
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

    /// OctoPod plugin for OctoPrint sent a remote notification to the iOS app about the print job. If this is a test then display a local notification.
    /// If not a test then instruct the Apple Watch app to update its complication. There is a 50 daily limit/budget for updating complications immediatelly
    /// after that we will use a fallback mechanism that will eventually update the complication
    /// - parameters:
    ///     - printerID: ID of the printer for which its progress and state is reported
    ///     - printerState: Printer state
    ///     - progressCompletion: % of progress of the print
    ///     - mediaURL: URL that holds a snapshot of the print
    ///     - test: True if the remote notification is a test
    ///     - forceUpdate: True uses #transferCurrentComplicationUserInfo that asks AppleWatch to update complication asap. This depends on budget availability. If no buget then use low priority messaging. Only applies to print completion progress
    ///     - completionHandler: Block of code to execute once refresh has been processed
    ///     - result: UIBackgroundFetchResult indicating if new data was processed
    func refresh(printerID: String, printerState: String, progressCompletion: Double?, mediaURL: String?, test: Bool?, forceComplicationUpdate: Bool?, completionHandler: @escaping (_ result: UIBackgroundFetchResult) -> Void) {
        if let idURL = URL(string: printerID), let printer = printerManager.getPrinterByObjectURL(url: idURL) {
            if test == true {
                self.checkCompletedJobLocalNotification(printerName: printer.name, state: printerState, mediaURL: mediaURL, completion: 100, test: true)
            } else {
                self.pushComplicationUpdate(printerName: printer.name, octopodPluginInstalled: printer.octopodPluginInstalled, state: printerState, mediaURL: mediaURL, completion: progressCompletion, forceUpdate: forceComplicationUpdate)
            }
            completionHandler(.newData)
        } else {
            // Unkown ID of printer
            completionHandler(.noData)
        }
    }

    /// iOS app has been woken up to execute its background task for fetching new content. If OctoPod plugin for OctoPrint
    /// is installed then do nothing. This is a fallback for users that haven't installed the plugin yet for real time notifications
    /// 
    /// Assumption: Runs in main thread
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
                restClient.connectToServer(serverURL: printer.hostname, apiKey: printer.apiKey, username: printer.username, password: printer.password, preemptive: printer.preemptiveAuthentication())
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
                        self.pushComplicationUpdate(printerName: printer.name, octopodPluginInstalled: printer.octopodPluginInstalled, state: state, mediaURL: nil, completion: progressCompletion, forceUpdate: false)
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
    
    func printerStateUpdated(event: CurrentStateEvent) {
        /// This notification is sent when iOS app is being used by user. This class listens to each event and if state has changed (or completion) then
        /// a push notification to Apple Watch app will be sent to update its complications (if daily budget allows)
        let context = printerManager.safePrivateContext()
        context.perform {
            if let printer = self.printerManager.getDefaultPrinter(context: context), let state = event.state {
                self.pushComplicationUpdate(printerName: printer.name, octopodPluginInstalled: printer.octopodPluginInstalled, state: state, mediaURL: nil, completion: event.progressCompletion, forceUpdate: false)
            }
        }
    }
    
    // MARK: - Private functions
    
    /// Push Apple Watch complication update only when printer changed state. If OctoPod plugin for OctoPrint is not installed then also use this time to send a local notification
    /// Complications also get updated when they run a background refresh or when user opened the Apple Watch app and it fetched new data
    ///
    /// Request to update compliation is always sent if printer changed state. It will first try to use #transferCurrentComplicationUserInfo if enough budget. Parameter **forceUpdate** is
    /// used only if printer is already printing and the only change is the completion %.
    ///
    /// If state did not change and is printing and *not forced* then request to update completion happens only if progress is 10% bigger than before and 10 minutes have passed
    /// since last update. Since it is not forced then #transferCurrentComplicationUserInfo is not going to be used.
    ///
    /// If state did not change and is printing and *forced* then only progress of 10% is considered and request will be made via #transferCurrentComplicationUserInfo so we depend
    /// on available budget. If not enough budget then fallback to other method.
    ///
    /// - parameters:
    ///     - printerName: Name of the printer for which its progress and state is reported
    ///     - octopodPluginInstalled: True if OctoPod plugin for OctoPrint is installed. When not installed then a local notification is created when print is done
    ///     - state: Printer state
    ///     - mediaURL: URL that holds a snapshot of the print
    ///     - completion: % of progress of the print
    ///     - forceUpdate: True uses #transferCurrentComplicationUserInfo that asks AppleWatch to update complication asap. This depends on budget availability. If no buget then use low priority messaging. Only applies to print completion progress
    fileprivate func pushComplicationUpdate(printerName: String, octopodPluginInstalled: Bool, state: String, mediaURL: String?, completion: Double?, forceUpdate: Bool?) {
        // Normalize state
        var pushState = state
        if state == "Printing from SD" {
            pushState = "Printing"
        } else if state.starts(with: "Offline (Error:") {
            pushState = "Offline"
        }

        // Check if state has changed since last refresh
        var lastState: (state: String, completion: Double?)?
        // Dictionary is not thread safe. Use sync for read operations
        self.accessQueue.sync {
            lastState = self.lastKnownState[printerName]
        }
        if lastState == nil || lastState?.state != state {
            if !octopodPluginInstalled, let completion = completion {
                // Send local notification if OctoPod plugin for OctoPrint is not installed
                checkCompletedJobLocalNotification(printerName: printerName, state: state, mediaURL: mediaURL, completion: completion, test: false)
            }
            // There is a budget of 50 pushes to the Apple Watch so let's only send relevant events
            // Ignore event with Printing and no completion
            if pushState != "Printing" || completion != nil {
                // Update last known state
                // Dictionary is not thread safe. Use async for write operations and a barrier to not let other tasks execute while we write
                self.accessQueue.async(flags: .barrier) {
                    self.lastKnownState[printerName] = (state, completion)
                }
                if pushState == "Offline" || pushState == "Operational" || pushState == "Printing" || pushState == "Paused" {
                    // Update complication with received data
                    self.watchSessionManager.updateComplications(printerName: printerName, printerState: pushState, completion: completion, useBudget: true)
                }
            }
            if #available(iOS 14, *) {
                // Refresh iOS 14 widgets as well (since we have a new printer state)
                WidgetCenter.shared.reloadAllTimelines()
            }
        } else if let completion = completion, pushState == "Printing" {
            // State is the same (still printing) and completion is not nil
            // so check if we should send a complication update or not
            self.watchSessionManager.optionalUpdateComplications(printerName: printerName, printerState: pushState, completion: completion, forceUpdate: forceUpdate ?? false)
            if #available(iOS 14, *) {
                if completion.remainder(dividingBy: 5.0) == 0 {
                    // Refresh iOS 14 widgets as well (since progress is multiple of 5). This prevents updating widget every time. Helps save battery
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
        }
    }
    
    fileprivate func checkCompletedJobLocalNotification(printerName: String, state: String, mediaURL: String?, completion: Double, test: Bool) {
        var sendLocalNotification = false
        var lastState: (state: String, completion: Double?)?
        self.accessQueue.sync {
            lastState = self.lastKnownState[printerName]
        }
        if let lastState = lastState {
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
