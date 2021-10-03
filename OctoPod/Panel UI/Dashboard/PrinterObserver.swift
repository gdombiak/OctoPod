import Foundation
import UIKit

class PrinterObserver: OctoPrintClientDelegate, OctoPrintPluginsDelegate {
    
    private let delegate: PrinterObserverDelegate
    private var octoPrintClient: OctoPrintClient?
    private let row: Int
    
    private var isDefaultPrinter: Bool = false
    
    var printerName: String = ""
    var printerStatus: String = "--"
    var progress: String = "--%"
    var printTime: String = "--"
    var printTimeLeft: String = "--"
    var printCompletion: String = "--"
    var jobFile: String?
    var layer: String?
    
    init(delegate: PrinterObserverDelegate, row: Int) {
        self.delegate = delegate
        self.row = row
    }
    
    // MARK: - Connection operations

    func connectToServer(printer: Printer) {
        printerName = printer.name
        isDefaultPrinter = printer.defaultPrinter

        if isDefaultPrinter {
            self.octoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
        } else {
            let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
            self.octoPrintClient = OctoPrintClient(printerManager: printerManager)
        }
        // Listen to events coming from OctoPrintClient
        octoPrintClient?.delegates.append(self)
        // Listen to changes to OctoPrint Plugin messages
        octoPrintClient?.octoPrintPluginsDelegates.append(self)

        
        if !isDefaultPrinter {
            octoPrintClient?.connectToServer(printer: printer)
        }
    }

    func disconnectFromServer() {
        if isDefaultPrinter {
            // Stop listening to changes from OctoPrintClient
            octoPrintClient?.remove(octoPrintClientDelegate: self)
            // Stop listening to changes to OctoPrint Plugin messages
            octoPrintClient?.remove(octoPrintPluginsDelegate: self)
        } else {
            octoPrintClient?.disconnectFromServer()
        }
    }

    // MARK: - OctoPrintClientDelegate
    
    func printerStateUpdated(event: CurrentStateEvent) {
        var changed = false
        
        if let state = event.state, state != printerStatus {
            self.printerStatus = state
            changed = true
        }

        if let progress = event.progressCompletion {
            let progressText = "\(String(format: "%.1f", progress))%"
            if progressText != self.progress {
                self.progress = progressText
                changed = true
            }
        }
        
        if let seconds = event.progressPrintTime {
            let newTime = UIUtils.secondsToPrintTime(seconds: seconds)
            if newTime != printTime {
                self.printTime = newTime
                changed = true
            }
        }

        if let seconds = event.progressPrintTimeLeft {
            let newTimeLeft = UIUtils.secondsToTimeLeft(seconds: seconds, includesApproximationPhrase: false, ifZero: "--")
            if newTimeLeft != printTimeLeft {
                self.printTimeLeft = newTimeLeft
                changed = true
            }
            let newPrintEstimatedCompletion = UIUtils.secondsToETA(seconds: seconds)
            if newPrintEstimatedCompletion != printCompletion {
                printCompletion = newPrintEstimatedCompletion
                changed = true
            }
        } else if event.progressPrintTime != nil {
            let newTimeLeft = NSLocalizedString("Still stabilizing", comment: "Print time is being calculated")
            if newTimeLeft != printTimeLeft {
                self.printTimeLeft = newTimeLeft
                self.printCompletion = ""
                changed = true
            }
        }
        
        if let file = event.printFile, let fileName = file.name {
            if fileName != self.jobFile {
                self.jobFile = fileName
                changed = true
            }
        }
        
        if changed {
            delegate.refreshItem(row: row, printerObserver: self)
        }
        delegate.currentStateUpdated(row: row, event: event)
    }
       
    // MARK: - OctoPrintPluginsDelegate

    func pluginMessage(plugin: String, data: NSDictionary) {
        if plugin == Plugins.DISPLAY_LAYER_PROGRESS {
            if let totalLayer = data["totalLayer"] as? String, let currentLayer = data["currentLayer"] as? String {
                let newLayer = "\(currentLayer) / \(totalLayer)"
                if newLayer != layer {
                    self.layer = newLayer
                    delegate.refreshItem(row: row, printerObserver: self)
                }
            }
        }
    }
}
