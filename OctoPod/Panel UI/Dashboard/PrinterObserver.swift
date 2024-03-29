import Foundation
import UIKit

class PrinterObserver: OctoPrintClientDelegate, OctoPrintPluginsDelegate {
    private static let SORT_BY_PREFERENCE = "PrinterObserverSortBy"

    enum SortBy: Int {
        case position = 1
        case alphabetical = 2
        case timeLeft = 3
    }
    
    private var delegate: PrinterObserverDelegate?
    private var octoPrintClient: OctoPrintClient?
    private var row: Int // Position in the UICollectionView. Position changes as sort changes
    
    private var isDefaultPrinter: Bool = false
    
    private let printerIndex: Int // Position of printer in list of printers as defined by user (in Settings)
    var printerName: String = ""
    var printerStatus: String = "--"
    var progress: String = "--%"
    var printTime: String = "--"
    var printTimeLeft: String = "--"
    var timeLeft: Int = Int.max
    var printCompletion: String = "--"
    var jobFile: String?
    var layer: String?
    
    init(delegate: PrinterObserverDelegate, row: Int, printerIndex: Int) {
        self.delegate = delegate
        self.row = row
        self.printerIndex = printerIndex
    }
    
    // MARK: - Connection operations

    func connectToServer(printer: Printer) {
        printerName = printer.name
        isDefaultPrinter = printer.defaultPrinter

        if isDefaultPrinter {
            self.octoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
        } else {
            let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
            let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()
            self.octoPrintClient = OctoPrintClient(printerManager: printerManager, appConfiguration: appConfiguration)
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
            // AppConfiguration got added as a listener so remove it so octoPrintClient is released from memory
            if let appConfig = octoPrintClient?.appConfiguration, let octoPrintClient = octoPrintClient {
                octoPrintClient.remove(octoPrintClientDelegate: appConfig)
                appConfig.remove(appConfigurationDelegate: octoPrintClient)
            }
        }
    }
    
    /// Discard this observer. This means that the observer will no longer be used. We can now
    /// close the connection and stop sending notification to the deleage
    func discard() {
        // Stop sending notification to delegate
        delegate = nil
        // Close connection
        disconnectFromServer()
        // Release reference so object is removed from memory
        octoPrintClient = nil
    }

    // MARK: - Sort operations
    
    /// Sort PrinterObservers by user prefered sort criteria
    class func sort(printers: Array<PrinterObserver>, by sortBy: SortBy?) -> Array<PrinterObserver> {
        var useSort: SortBy
        if let newSortBy = sortBy {
            useSort = newSortBy
            // Store sort by as user preference
            let defaults = UserDefaults.standard
            defaults.set(newSortBy.rawValue, forKey: SORT_BY_PREFERENCE)
        } else {
            // Use default sort criteria based on user preferences
            useSort = defaultSortCriteria()
        }

        let sortedPrinters: Array<PrinterObserver>
        switch useSort {
        case .position:
            sortedPrinters = sortByPosition(printers: printers)
        case SortBy.alphabetical:
            sortedPrinters = sortByAlphabeticalOrder(printers: printers)
        case SortBy.timeLeft:
            sortedPrinters = sortByTimeLeft(printers: printers)
        }
        // Update position of printer in PrintersDashboardViewController
        for (index, printer) in sortedPrinters.enumerated() {
            printer.row = index
        }
        return sortedPrinters
    }
    
    /// Returns default sort criteria to use (based on user preferences)
    class func defaultSortCriteria() -> SortBy {
        let defaults = UserDefaults.standard
        if let storedValue = defaults.object(forKey: SORT_BY_PREFERENCE) as? Int {
            return SortBy(rawValue: storedValue)!
        }
        return SortBy.position
    }
    
    /// Sorts printers by position
    fileprivate class func sortByPosition(printers: Array<PrinterObserver>) -> Array<PrinterObserver> {
        return printers.sorted { (printer1: PrinterObserver, printer2: PrinterObserver) -> Bool in
            return printer1.printerIndex < printer2.printerIndex
        }
    }
    
    /// Sorts printers by alphabetical order
    fileprivate class func sortByAlphabeticalOrder(printers: Array<PrinterObserver>) -> Array<PrinterObserver> {
        return printers.sorted { (printer1: PrinterObserver, printer2: PrinterObserver) -> Bool in
            return printer1.printerName < printer2.printerName
        }
    }
    
    /// Sorts printers by time left
    fileprivate class func sortByTimeLeft(printers: Array<PrinterObserver>) -> Array<PrinterObserver> {
        return printers.sorted { (printer1: PrinterObserver, printer2: PrinterObserver) -> Bool in
            if printer1.timeLeft == printer2.timeLeft {
                // For printers with exact same time left we need to sort by name
                return printer1.printerName < printer2.printerName
            }
            return printer1.timeLeft < printer2.timeLeft
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
                self.timeLeft = seconds
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
                self.timeLeft = Int.max - 1 // When sorted by time left, this one will appear before inactive printers
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
            delegate?.refreshItem(row: row, printerObserver: self)
        }
        delegate?.currentStateUpdated(row: row, event: event)
    }
       
    // MARK: - OctoPrintPluginsDelegate

    func pluginMessage(plugin: String, data: NSDictionary) {
        if plugin == Plugins.DISPLAY_LAYER_PROGRESS {
            if let totalLayer = data["totalLayer"] as? String, let currentLayer = data["currentLayer"] as? String {
                let newLayer = "\(currentLayer) / \(totalLayer)"
                if newLayer != layer {
                    self.layer = newLayer
                    delegate?.refreshItem(row: row, printerObserver: self)
                }
            }
        }
    }
}
