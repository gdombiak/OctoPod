import Foundation
import Intents

class IntentsDonations {
    
    private static let GROUP_IDENTIFIER = "org.OctoPod.Intentions"  // Unique & Global idenfier for all Intents created by this app
    
    // MARK: - Create functions

    static func donateBedTemp(printer: Printer, temperature: Int) {
        // Intent only available on iOS 12 or neweer
        if #available(iOS 12.0, *) {
            let intent = SetBedTempIntent()
            intent.printer = printer.name
            intent.hostname = printer.hostname
            intent.apiKey = printer.apiKey
            intent.username = printer.username
            intent.password = printer.password
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
        // Intent only available on iOS 12 or neweer
        if #available(iOS 12.0, *) {
            let intent = SetToolTempIntent()
            intent.printer = printer.name
            intent.hostname = printer.hostname
            intent.apiKey = printer.apiKey
            intent.username = printer.username
            intent.password = printer.password
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

    static func donatePauseJob(printer: Printer) {
        // Intent only available on iOS 12 or neweer
        if #available(iOS 12.0, *) {
            let intent = PauseJobIntent()
            intent.printer = printer.name
            intent.hostname = printer.hostname
            intent.apiKey = printer.apiKey
            intent.username = printer.username
            intent.password = printer.password
            intent.suggestedInvocationPhrase = String(format: NSLocalizedString("Pause current print job", comment: "Siri suggested phrase"), printer.name)
            
            donateIntent(intent: intent, printer: printer, identifierSuffix: "Pause")
        }
    }

    static func donateResumeJob(printer: Printer) {
        // Intent only available on iOS 12 or neweer
        if #available(iOS 12.0, *) {
            let intent = ResumeJobIntent()
            intent.printer = printer.name
            intent.hostname = printer.hostname
            intent.apiKey = printer.apiKey
            intent.username = printer.username
            intent.password = printer.password
            intent.suggestedInvocationPhrase = String(format: NSLocalizedString("Resume current print job", comment: "Siri suggested phrase"), printer.name)
            
            donateIntent(intent: intent, printer: printer, identifierSuffix: "Resume")
        }
    }

    static func donateCancelJob(printer: Printer) {
        // Intent only available on iOS 12 or neweer
        if #available(iOS 12.0, *) {
            let intent = CancelJobIntent()
            intent.printer = printer.name
            intent.hostname = printer.hostname
            intent.apiKey = printer.apiKey
            intent.username = printer.username
            intent.password = printer.password
            intent.suggestedInvocationPhrase = String(format: NSLocalizedString("Cancel current print job", comment: "Siri suggested phrase"), printer.name)
            
            donateIntent(intent: intent, printer: printer, identifierSuffix: "Cancel")
        }
    }
    
    static func donateRestartJob(printer: Printer) {
        // Intent only available on iOS 12 or neweer
        if #available(iOS 12.0, *) {
            let intent = RestartJobIntent()
            intent.printer = printer.name
            intent.hostname = printer.hostname
            intent.apiKey = printer.apiKey
            intent.username = printer.username
            intent.password = printer.password
            intent.suggestedInvocationPhrase = String(format: NSLocalizedString("Restart current print job", comment: "Siri suggested phrase"), printer.name)
            
            donateIntent(intent: intent, printer: printer, identifierSuffix: "Restart")
        }
    }
    
    static func donateRemainingTime(printer: Printer) {
        // Intent only available on iOS 12 or neweer
        if #available(iOS 12.0, *) {
            let intent = RemainingTimeIntent()
            intent.printer = printer.name
            intent.hostname = printer.hostname
            intent.apiKey = printer.apiKey
            intent.username = printer.username
            intent.password = printer.password
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
        // Donate all job actions
        donatePauseJob(printer: printer)
        donateResumeJob(printer: printer)
        donateCancelJob(printer: printer)
        donateRestartJob(printer: printer)
        // Remaining print time
        donateRemainingTime(printer: printer)
    }
    
    // MARK: - Delete functions

    static func deletePrinterIntents(printer: Printer) {
        INInteraction.delete(with: "\(GROUP_IDENTIFIER).\(printer.objectID)") { (error: Error?) in
            if let error = error {
                NSLog("Failed to delete donated interactions for printer \(printer.name). Error: \(error.localizedDescription)")
            } else {
                NSLog("Printer donated Interactions deleted")
            }
        }
    }
    
    static func deleteAllDonatedIntents() {
        INInteraction.deleteAll { (error: Error?) in
            if let error = error {
                NSLog("Failed to delete all donated interactions. Error: \(error.localizedDescription)")
            } else {
                NSLog("All donated Interactions deleted")
            }
        }
    }
    
    // MARK: - Private functions
    
    fileprivate class func donateIntent(intent: INIntent, printer: Printer, identifierSuffix: String) {
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.identifier = "\(GROUP_IDENTIFIER).\(identifierSuffix)"
        interaction.groupIdentifier = "\(GROUP_IDENTIFIER).\(printer.objectID)"

        interaction.donate { (error) in
            if let error = error {
                NSLog("Interaction donation failed: \(error.localizedDescription)")
            } else {
                NSLog("Successfully donated interaction")
            }
        }

    }
}
