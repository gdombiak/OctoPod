import Foundation
import Intents

class IntentsDonations {
    
    private static let GROUP_IDENTIFIER = "org.OctoPod.Intentions"  // Unique & Global idenfier for all Intents created by this app
    private static let DONATIONS_INITIALIZED = "IntentsDonations.init"
    
    // MARK: - Donate Printer Intents

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
    
    static func donateChamberTemp(printer: Printer, temperature: Int) {
        // Intent only available on iOS 12 or newer
        if #available(iOS 12.0, *) {
            let intent = SetChamberTempIntent()
            intent.printer = printer.name
            intent.printerURL = printer.objectID.uriRepresentation().absoluteString
            intent.temperature = temperature as NSNumber
            if temperature > 0 {
                intent.suggestedInvocationPhrase = String(format: NSLocalizedString("Warm up heated chamber", comment: "Siri suggested phrase"), printer.name)
            } else {
                intent.suggestedInvocationPhrase = String(format: NSLocalizedString("Cool down heated chamber", comment: "Siri suggested phrase"), printer.name)
            }
            
            donateIntent(intent: intent, printer: printer, identifierSuffix: "Chamber")
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
    
    static func donateSystemCommand(printer: Printer, action: String, source: String, name: String) {
        // Intent only available on iOS 12 or newer
        if #available(iOS 12.0, *) {
            let intent = SystemCommandIntent()
            intent.printer = printer.name
            intent.printerURL = printer.objectID.uriRepresentation().absoluteString
            intent.commandAction = action
            intent.commandSource = source
            intent.commandName = name
            intent.suggestedInvocationPhrase = String(format: NSLocalizedString("Execute System Command", comment: "Siri suggested phrase"), printer.name)
            
            donateIntent(intent: intent, printer: printer, identifierSuffix: "SystemCommand")
        }
    }
    
    /// Suggest Siri shortcuts for the printer. These are intents created when a Printer is added or modified
    /// The other donations are done based on user interaction with the app
    static func donatePrinterIntents(printer: Printer) {
        // Donate convenient shortcut for cooling down bed and tool 0 with a single command
        // Individual cool down will be donated if/when user uses that feature. Not donated by default to reduce clutter
        // Setting up temps is not donated by default since this is user/printer/filament specific
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
    
    // MARK: - Donate Enclosure Plugin Intents
    
    static func donateEnclosureTurnOn(printer: Printer, switchLabel: String) {
        // Intent only available on iOS 12 or newer
        if #available(iOS 12.0, *) {
            let intent = EnclosureTurnOnIntent()
            intent.printer = printer.name
            intent.printerURL = printer.objectID.uriRepresentation().absoluteString
            intent.label = switchLabel
            intent.suggestedInvocationPhrase = String(format: NSLocalizedString("Turn on Enclosure switch", comment: "Siri suggested phrase"), printer.name)
            
            donateIntent(intent: intent, printer: printer, identifierSuffix: "EnclosureTurnOn")
        }
    }
    
    static func donateEnclosureTurnOff(printer: Printer, switchLabel: String) {
        // Intent only available on iOS 12 or newer
        if #available(iOS 12.0, *) {
            let intent = EnclosureTurnOffIntent()
            intent.printer = printer.name
            intent.printerURL = printer.objectID.uriRepresentation().absoluteString
            intent.label = switchLabel
            intent.suggestedInvocationPhrase = String(format: NSLocalizedString("Turn off Enclosure switch", comment: "Siri suggested phrase"), printer.name)

            donateIntent(intent: intent, printer: printer, identifierSuffix: "EnclosureTurnOff")
        }
    }
    
    // MARK: - Delete Intents

    /// Delete donate Siri commands that relate to the printer. This includes Palette intents as well
    static func deletePrinterIntents(printer: Printer) {
        INInteraction.delete(with: groupIdentifier(printer: printer)) { (error: Error?) in
            if let error = error {
                NSLog("Failed to delete donated intentions for printer \(printer.name). Error: \(error.localizedDescription)")
            } else {
                NSLog("Printer donated Intentions deleted")
            }
        }
    }
    
    /// Delete all donated Siri commands made by the app
    static func deleteAllDonatedIntents(done: ((Error?) -> Void)?) {
        INInteraction.deleteAll { (error: Error?) in
            if let error = error {
                NSLog("Failed to delete all donated intentions. Error: \(error.localizedDescription)")
            } else {
                NSLog("All donated Intentions deleted")
            }
            done?(error)
        }
    }
    
    // MARK: - Donate Palette Intents
    
    /// Donate all Siri commands to control Palette
    static func donatePaletteIntents(printer: Printer) {
        donatePaletteConnect(printer: printer)
        donatePaletteDisconnect(printer: printer)
        donatePaletteClear(printer: printer)
        donatePaletteCut(printer: printer)
        donatePalettePingStats(printer: printer)
    }

    /// Delete Siri commands that relate to Palette
    static func deletePaletteIntents(printer: Printer) {
        var toDelete = Array<String>()
        toDelete.append(intentIdentifier(printer: printer, identifierSuffix: "PaletteConnect"))
        toDelete.append(intentIdentifier(printer: printer, identifierSuffix: "PaletteDisconnect"))
        toDelete.append(intentIdentifier(printer: printer, identifierSuffix: "PaletteClear"))
        toDelete.append(intentIdentifier(printer: printer, identifierSuffix: "PaletteCut"))
        INInteraction.delete(with: toDelete) { (error: Error?) in
            if let error = error {
                NSLog("Failed to delete donated Palette intentions for printer \(printer.name). Error: \(error.localizedDescription)")
            } else {
                NSLog("Palette donated Intentions deleted")
            }
        }
    }

    static func donatePaletteConnect(printer: Printer) {
        // Intent only available on iOS 12 or newer
        if #available(iOS 12.0, *) {
            let intent = PaletteConnectIntent()
            intent.printer = printer.name
            intent.printerURL = printer.objectID.uriRepresentation().absoluteString
            
            donateIntent(intent: intent, printer: printer, identifierSuffix: "PaletteConnect")
        }
    }
    
    static func donatePaletteDisconnect(printer: Printer) {
        // Intent only available on iOS 12 or newer
        if #available(iOS 12.0, *) {
            let intent = PaletteDisconnectIntent()
            intent.printer = printer.name
            intent.printerURL = printer.objectID.uriRepresentation().absoluteString
            
            donateIntent(intent: intent, printer: printer, identifierSuffix: "PaletteDisconnect")
        }
    }

    static func donatePaletteClear(printer: Printer) {
        // Intent only available on iOS 12 or newer
        if #available(iOS 12.0, *) {
            let intent = PaletteClearIntent()
            intent.printer = printer.name
            intent.printerURL = printer.objectID.uriRepresentation().absoluteString
            
            donateIntent(intent: intent, printer: printer, identifierSuffix: "PaletteClear")
        }
    }
    
    static func donatePaletteCut(printer: Printer) {
        // Intent only available on iOS 12 or newer
        if #available(iOS 12.0, *) {
            let intent = PaletteCutIntent()
            intent.printer = printer.name
            intent.printerURL = printer.objectID.uriRepresentation().absoluteString
            
            donateIntent(intent: intent, printer: printer, identifierSuffix: "PaletteCut")
        }
    }

    static func donatePalettePingStats(printer: Printer) {
        // Intent only available on iOS 12 or newer
        if #available(iOS 12.0, *) {
            let intent = PalettePingStatsIntent()
            intent.printer = printer.name
            intent.printerURL = printer.objectID.uriRepresentation().absoluteString
            
            donateIntent(intent: intent, printer: printer, identifierSuffix: "PalettePingStats")
        }
    }
    
    // MARK: - Private functions
    
    fileprivate class func donateIntent(intent: INIntent, printer: Printer, identifierSuffix: String) {
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.identifier = intentIdentifier(printer: printer, identifierSuffix: identifierSuffix)
        interaction.groupIdentifier = groupIdentifier(printer: printer)

        interaction.donate { (error) in
            if let error = error {
                NSLog("Interaction donation failed: \(error.localizedDescription)")
            } else {
                NSLog("Successfully donated interaction for intent: \(intent)")
            }
        }
    }
    
    fileprivate class func intentIdentifier(printer: Printer, identifierSuffix: String) -> String {
        return "\(GROUP_IDENTIFIER).\(printer.objectID.uriRepresentation()).\(identifierSuffix))"
    }

    fileprivate class func groupIdentifier(printer: Printer) -> String {
        return "\(GROUP_IDENTIFIER).\(printer.objectID.uriRepresentation())"
    }
}
