import Foundation
import ActivityKit

class LiveActivitiesManager: OctoPrintClientDelegate {
    
    private let printerManager: PrinterManager!
    private let octoprintClient: OctoPrintClient!
    
    init(printerManager: PrinterManager, octoprintClient: OctoPrintClient) {
        self.printerManager = printerManager
        self.octoprintClient = octoprintClient
        
        // Listen to events coming from OctoPrintClient
        octoprintClient.delegates.append(self)
    }
    
    func start() {
        // Do nothing. Will react to print events to start live actiities
        // Added this method to force creation of this instance when iOS app starts
    }
    
    // MARK: - OctoPrintClientDelegate
    
    func printerStateUpdated(event: CurrentStateEvent) {
        if #available(iOS 16.2, *) {
            // For Live Activities to work we need: iOS16.2 and user allowed Live Activities for OctoPod
            // If OctoPod plugin is NOT installed then live activity widget will show a warning asking user to install plugin
            if let printer = printerManager.getDefaultPrinter(), let printing = event.printing, let paused = event.paused, let pausing = event.pausing, ActivityAuthorizationInfo().areActivitiesEnabled {
                let targetURLSafePrinter = printer.objectID.uriRepresentation().absoluteString
                let isPrinting = printing || paused || pausing
                var found = false
                for activity in Activity<PrintJobAttributes>.activities {
                    if activity.attributes.urlSafePrinter == targetURLSafePrinter {
                        if isPrinting {
                            if activity.activityState == .active {
                                if let state = event.state, let progress = event.progressCompletion, let seconds = event.progressPrintTimeLeft {
                                    // Update Live Activity while printer is printing
                                    let intProgress = Int(progress.rounded())
                                    if activity.content.state.printerStatus != state || activity.content.state.completion != intProgress || activity.content.state.printTimeLeft != seconds {
                                        Task {
                                            let updatedContentState = PrintJobAttributes.ContentState(printerStatus: state, completion: intProgress, printTimeLeft: seconds)
                                            let updatedContent = ActivityContent(state: updatedContentState, staleDate: Calendar.current.date(byAdding: .minute, value: 30, to: Date())!)
                                            await activity.update(updatedContent)
                                        }
                                    }
                                }
                            } else {
                                // Live Activity has ended (maybe due to 8 - 12 hours limit) or user dismissed it
                                // Remove ended Live Actvitity and unregister from OctoPod plugin
                                removeAndUnregisterActivity(event, printer, activity)
                                // since not active then ignore this one so we can find an active one if exists
                                continue
                            }
                        } else {
                            // Remove Live Actvitity and unregister from OctoPod plugin
                            removeAndUnregisterActivity(event, printer, activity)
                        }
                        found = true
                        break
                    }
                }
                if !found && isPrinting {
                    // Create new Live Activity if printer is printing
                    
                    // Create the activity attributes and activity content objects.
                    var printerStatus = ""
                    if let state = event.state {
                        printerStatus = state
                    }
                    var completion = 0
                    if let progress = event.progressCompletion {
                        completion = Int(progress.rounded())
                    }
                    var printTimeLeft = 0
                    if let seconds = event.progressPrintTimeLeft {
                        printTimeLeft = seconds
                    }
                    var printFileName = ""
                    if let fileName = event.printFile?.name {
                        printFileName = fileName
                    } else {
                        // Ignore events with no file name. Next event will include file name so we can create proper Live Activity
                        // Filename is displayed at the end of the print
                        return
                    }
                    
                    let initialContentState = PrintJobAttributes.ContentState(printerStatus: printerStatus, completion: completion, printTimeLeft: printTimeLeft)
                    let activityAttributes = PrintJobAttributes(urlSafePrinter: targetURLSafePrinter, printerName: printer.name, printFileName: printFileName, pluginInstalled: printer.octopodPluginInstalled)
                    
                    let activityContent = ActivityContent(state: initialContentState, staleDate: Calendar.current.date(byAdding: .minute, value: 30, to: Date())!)
                    
                    // Start the Live Activity.
                    do {
                        let activity = try Activity.request(attributes: activityAttributes, content: activityContent, pushType: .token)
                        if printer.octopodPluginInstalled {
                            // Register pushToken for updating live activity
                            // Create tasks that keeps listening as push tokens rotate for this live activity
                            Task {
                                for await data in activity.pushTokenUpdates {
                                    let token = data.map {String(format: "%02x", $0)}.joined()
                                    octoprintClient.registerLiveActivityAPNSToken(activityID: activity.id, token: token) { (success: Bool, error: Error?, response: HTTPURLResponse) in
                                        if !success {
                                            // Handle error
                                            NSLog("Error registering Live Activity. HTTP status code \(response.statusCode)")
                                        }
                                    }
                                }
                                NSLog("STOPPED listening for push notifications for LA \(activity.id)")
                            }
                        }
                    } catch (let error) {
                        NSLog("Error requesting Live Activity \(error.localizedDescription).")
                    }
                }
            }
        }
    }
    
    @available(iOS 16.2, *)
    fileprivate func removeAndUnregisterActivity(_ event: CurrentStateEvent, _ printer: Printer, _ activity: Activity<PrintJobAttributes>) {
        Task {
            var printerStatus = ""
            if let state = event.state {
                printerStatus = state
            }
            let finalContentState = PrintJobAttributes.ContentState(printerStatus: printerStatus, completion: 100, printTimeLeft: 0)
            let finalContent = ActivityContent(state: finalContentState, staleDate: Calendar.current.date(byAdding: .minute, value: 30, to: Date())!)
            await activity.end(finalContent, dismissalPolicy: .immediate)
            
            octoprintClient.unregisterLiveActivityAPNSToken(activityID: activity.id) { (success: Bool, error: Error?, response: HTTPURLResponse) in
                if !success {
                    // Handle error
                    NSLog("Error unregistering Live Activity. HTTP status code \(response.statusCode)")
                }
            }
        }
    }
}
