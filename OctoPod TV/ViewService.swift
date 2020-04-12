import Foundation
import UIKit

class ViewService: ObservableObject, OctoPrintClientDelegate, OctoPrintPluginsDelegate {
    @Published var printerStatus: String = "--"
    @Published var printingFile: String = "--"
    @Published var progress: String = "--%"
    @Published var printTime: String = "--"
    @Published var printTimeLeft: String = "--"
    @Published var printEstimatedCompletion: String = "--"
    @Published var tool0Actual: String = "--C"
    @Published var tool0Target: String = "--C"
    @Published var bedActual: String = "--C"
    @Published var bedTarget: String = "--C"
    @Published var currentHeight: String?
    @Published var layer: String?

    @Published var printing: Bool?  // This could represent that printer is printing or printer is uploading file to SD Card. IOW, this means if printer is busy
    @Published var paused: Bool?
    @Published var pausing: Bool?
    @Published var cancelling: Bool?
    @Published var lastKnownPrintFile: PrintFile?

    var octoPrintClient: OctoPrintClient!
    
    init() {
        let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()

        self.octoPrintClient = OctoPrintClient(printerManager: printerManager)
        self.clearValues()

        // Listen to events coming from OctoPrintClient
        octoPrintClient.delegates.append(self)

        // Listen to changes to OctoPrint Plugin messages
        octoPrintClient.octoPrintPluginsDelegates.append(self)
    }
    
    func clearValues() {
        printerStatus = "--"
        printingFile = "--"
        progress = "--%"
        printTime = "--"
        printTimeLeft = "--"
        printEstimatedCompletion = "--"
        tool0Actual = "--C"
        tool0Target = "--C"
        bedActual = "--C"
        bedTarget = "--C"
        currentHeight = nil
        layer = nil
        
        printing = nil
        paused = nil
        pausing = nil
        cancelling = nil
        lastKnownPrintFile = nil
    }
    
    // MARK: - Connection handling

    func connectToServer(printer: Printer) {
        octoPrintClient.connectToServer(printer: printer)        
    }

    func disconnectFromServer() {
        octoPrintClient.disconnectFromServer()
    }

    // MARK: - File operations

    /// Prints the specified file
    func printFile(origin: String, path: String, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintClient.printFile(origin: origin, path: path, callback: callback)
    }
    
    // MARK: - Job operations

    func currentJobInfo(callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        octoPrintClient.currentJobInfo(callback: callback)
    }
    
    func pauseCurrentJob(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintClient.pauseCurrentJob(callback: callback)
    }

    func resumeCurrentJob(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintClient.resumeCurrentJob(callback: callback)
    }
    
    func cancelCurrentJob(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintClient.cancelCurrentJob(callback: callback)
    }
    
    // There needs to be an active job that has been paused in order to be able to restart
    func restartCurrentJob(callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        octoPrintClient.restartCurrentJob(callback: callback)
    }
    
    // MARK: - OctoPrintClientDelegate
    
    func notificationAboutToConnectToServer() {
        self.clearValues()
    }
    
    func printerStateUpdated(event: CurrentStateEvent) {
        // Update properties from event. This will fire event that will refresh UI
        DispatchQueue.main.async {
            if let state = event.state {
                self.printerStatus = state
            }

            if let printFile = event.printFile, let printFileName = printFile.name {
                self.printingFile = printFileName
            }

            if let progress = event.progressCompletion {
                let progressText = String(format: "%.1f", progress)
                self.progress = "\(progressText)%"
            }

            if let seconds = event.progressPrintTime {
                self.printTime = self.secondsToPrintTime(seconds: seconds)
            }

            if let seconds = event.progressPrintTimeLeft {
                self.printTimeLeft = UIUtils.secondsToTimeLeft(seconds: seconds, includesApproximationPhrase: false, ifZero: "")
                self.printEstimatedCompletion = UIUtils.secondsToETA(seconds: seconds)
            } else if event.progressPrintTime != nil {
                self.printTimeLeft = NSLocalizedString("Still stabilizing", comment: "Print time is being calculated")
                self.printEstimatedCompletion = ""
            }

            if let tool0Actual = event.tool0TempActual {
                self.tool0Actual = "\(String(format: "%.1f", tool0Actual)) C"
            }
            if let tool0Target = event.tool0TempTarget {
                self.tool0Target = "\(String(format: "%.0f", tool0Target)) C"
            }

            if let bedActual = event.bedTempActual {
                self.bedActual = "\(String(format: "%.1f", bedActual)) C"
            }
            if let bedTarget = event.bedTempTarget {
                self.bedTarget = "\(String(format: "%.0f", bedTarget)) C"
            }
            self.printing = event.printing
            self.pausing = event.pausing
            self.paused = event.paused
            self.cancelling = event.cancelling

            self.lastKnownPrintFile = event.printFile
        }
    }
    
    func handleConnectionError(error: Error?, response: HTTPURLResponse) {
        // TODO Update (new) variable for error message
    }
    
    func websocketConnected() {
        // TODO Clean up (new) variable for error message
    }

    func websocketConnectionFailed(error: Error) {
        // TODO Update (new) variable for error message
    }
    
    // MARK: - OctoPrintPluginsDelegate
    
    func pluginMessage(plugin: String, data: NSDictionary) {
        if plugin == Plugins.DISPLAY_LAYER_PROGRESS {
            if let totalLayer = data["totalLayer"] as? String, let currentLayer = data["currentLayer"] as? String, let currentHeight = data["currentHeightFormatted"] as? String, let totalHeight = data["totalHeightFormatted"] as? String {
                // Refresh UI
                DispatchQueue.main.async {
                    self.currentHeight = "\(currentHeight) / \(totalHeight)"
                    self.layer = "\(currentLayer) / \(totalLayer)"
                }
            }
        }
    }

    // MARK: - Private functions

    /// Converts number of seconds into a string that represents time (e.g. 23h 10m)
    func secondsToPrintTime(seconds: Int) -> String {
        let duration = TimeInterval(seconds)
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .brief
        formatter.allowedUnits = [ .day, .hour, .minute, .second ]
        formatter.zeroFormattingBehavior = [ .default ]
        return formatter.string(from: duration)!
    }
}
