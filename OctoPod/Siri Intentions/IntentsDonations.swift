import Foundation
import Intents

class IntentsDonations {
    
    private static let GROUP_IDENTIFIER = "org.OctoPod.Intentions"  // Unique & Global idenfier for all Intents created by this app
    private static let DONATIONS_INITIALIZED = "IntentsDonations.init"
    
    // MARK: - Create functions

    static func donateBedTemp(printer: Printer, temperature: Int) {
        // Intent only available on iOS 12 or newer
        if #available(iOS 12.0, *) {
            let intent = SetBedTempIntent()
            intent.printer = printer.name
            intent.printerURL = printer.objectID.uriRepresentation().absoluteString
            intent.temperature = temperature as NSNumber
            if temperature > 0 {
                intent.suggestedInvocationPhrase = String(format: NSLocalizedString("Warm up printer bed", comment: "Siri suggested phrase"), printer.name)
            } else {
                intent.suggestedInvocationPhrase = String(format: NSLocalizedString("Cool down printer bed", comment: "Siri suggested phrase"), printer.name)
            }
            
            donateIntent(intent: intent, printer: printer, identifierSuffix: "Bed")
        }
    }
    
    static func donateToolTemp(printer: Printer, tool: Int, temperature: Int) {
        // Intent only available on iOS 12 or newer
        if #available(iOS 12.0, *) {
            let intent = SetToolTempIntent()
            intent.printer = printer.name
            intent.printerURL = printer.objectID.uriRepresentation().absoluteString
            intent.tool = tool as NSNumber
            intent.temperature = temperature as NSNumber
            if temperature > 0 {
                intent.suggestedInvocationPhrase = String(format: NSLocalizedString("Warm up printer extruder", comment: "Siri suggested phrase"), printer.name)
            } else {
                intent.suggestedInvocationPhrase = String(format: NSLocalizedString("Cool down printer extruder", comment: "Siri suggested phrase"), printer.name)
            }
            
            donateIntent(intent: intent, printer: printer, identifierSuffix: "Tool")
        }
    }
    
    static func donateCoolDownPrinter(printer: Printer) {
        // Intent only available on iOS 12 or newer
        if #available(iOS 12.0, *) {
            let intent = CoolDownPrinterIntent()
            intent.printer = printer.name
            intent.printerURL = printer.objectID.uriRepresentation().absoluteString
            intent.suggestedInvocationPhrase = String(format: NSLocalizedString("Cool down printer", comment: "Siri suggested phrase"), printer.name)
            
            donateIntent(intent: intent, printer: printer, identifierSuffix: "CoolDownPrinter")
        }
    }

    static func donatePauseJob(printer: Printer) {
        // Intent only available on iOS 12 or newer
        if #available(iOS 12.0, *) {
            let intent = PauseJobIntent()
            intent.printer = printer.name
            intent.printerURL = printer.objectID.uriRepresentation().absoluteString
            intent.suggestedInvocationPhrase = String(format: NSLocalizedString("Pause current print job", comment: "Siri suggested phrase"), printer.name)
            
            donateIntent(intent: intent, printer: printer, identifierSuffix: "Pause")
        }
    }

    static func donateResumeJob(printer: Printer) {
        // Intent only available on iOS 12 or newer
        if #available(iOS 12.0, *) {
            let intent = ResumeJobIntent()
            intent.printer = printer.name
            intent.printerURL = printer.objectID.uriRepresentation().absoluteString
            intent.suggestedInvocationPhrase = String(format: NSLocalizedString("Resume current print job", comment: "Siri suggested phrase"), printer.name)
            
            donateIntent(intent: intent, printer: printer, identifierSuffix: "Resume")
        }
    }

    static func donateCancelJob(printer: Printer) {
        // Intent only available on iOS 12 or newer
        if #available(iOS 12.0, *) {
            let intent = CancelJobIntent()
            intent.printer = printer.name
            intent.printerURL = printer.objectID.uriRepresentation().absoluteString
            intent.suggestedInvocationPhrase = String(format: NSLocalizedString("Cancel current print job", comment: "Siri suggested phrase"), printer.name)
            
            donateIntent(intent: intent, printer: printer, identifierSuffix: "Cancel")
        }
    }
    
    static func donateRestartJob(printer: Printer) {
        // Intent only available on iOS 12 or newer
        if #available(iOS 12.0, *) {
            let intent = RestartJobIntent()
            intent.printer = printer.name
            intent.printerURL = printer.objectID.uriRepresentation().absoluteString
            intent.suggestedInvocationPhrase = String(format: NSLocalizedString("Restart current print job", comment: "Siri suggested phrase"), printer.name)
            
            donateIntent(intent: intent, printer: printer, identifierSuffix: "Restart")
        }
    }
    
    static func donateRemainingTime(printer: Printer) {
        // Intent only available on iOS 12 or newer
        if #available(iOS 12.0, *) {
            let intent = RemainingTimeIntent()
            intent.printer = printer.name
            intent.printerURL = printer.objectID.uriRepresentation().absoluteString
            intent.suggestedInvocationPhrase = String(format: NSLocalizedString("Remaining time current print job", comment: "Siri suggested phrase"), printer.name)
            
            donateIntent(intent: intent, printer: printer, identifierSuffix: "Remaining")
        }
    }
    
    // Suggest Siri shortcuts for the printer. These are intents created when a Printer is added or modified
    // The other donations are done based on user interaction with the app
    static func donatePrinterIntents(printer: Printer) {
        // Donate cool down bed (warm up is not suggested since we do not know desired temperatures of user)
        donateBedTemp(printer: printer, temperature: 0)
        // Donate cool down extruder (warm up is not suggested since we do not know desired temperatures of user)
        // Do not donate second extruder since we do not know if there is one
        donateToolTemp(printer: printer, tool: 0, temperature: 0)
        // Donate convenient shortcut for cooling down bed and tool 0 with a single command
        donateCoolDownPrinter(printer: printer)
        // Donate all job actions
        donatePauseJob(printer: printer)
        donateResumeJob(printer: printer)
        donateCancelJob(printer: printer)
        donateRestartJob(printer: printer)
        // Remaining print time
        donateRemainingTime(printer: printer)
    }

    // Do a one time initialization for existing printers. This means that intents will
    // be donated for existing printers but this will be done only once. This is needed
    // for existing OctoPod installations that are running 2.0 or older and updated to 2.1
    // or newer. After this initial initialization, as new printers get added then a donation
    // will be done
    static func initIntentsForAllPrinters(printerManager: PrinterManager, force: Bool = false) {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: DONATIONS_INITIALIZED) && !force {
            return
        }
        // Run initialization only once
        for printer in printerManager.getPrinters() {
            donatePrinterIntents(printer: printer)
        }
        defaults.set(true, forKey: DONATIONS_INITIALIZED)
    }
    
    // MARK: - Delete functions

    static func deletePrinterIntents(printer: Printer) {
        INInteraction.delete(with: groupIdentifier(printer: printer)) { (error: Error?) in
            if let error = error {
                NSLog("Failed to delete donated interactions for printer \(printer.name). Error: \(error.localizedDescription)")
            } else {
                NSLog("Printer donated Interactions deleted")
            }
        }
    }
    
    static func deleteAllDonatedIntents(done: ((Error?) -> Void)?) {
        INInteraction.deleteAll { (error: Error?) in
            if let error = error {
                NSLog("Failed to delete all donated interactions. Error: \(error.localizedDescription)")
            } else {
                NSLog("All donated Interactions deleted")
            }
            done?(error)
        }
    }
    
    // MARK: - Private functions
    
    fileprivate class func donateIntent(intent: INIntent, printer: Printer, identifierSuffix: String) {
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.identifier = "\(GROUP_IDENTIFIER).\(identifierSuffix)"
        interaction.groupIdentifier = groupIdentifier(printer: printer)

        interaction.donate { (error) in
            if let error = error {
                NSLog("Interaction donation failed: \(error.localizedDescription)")
            } else {
                NSLog("Successfully donated interaction")
            }
        }
    }
    
    fileprivate class func groupIdentifier(printer: Printer) -> String {
        return "\(GROUP_IDENTIFIER).\(printer.objectID.uriRepresentation())"
    }
}
