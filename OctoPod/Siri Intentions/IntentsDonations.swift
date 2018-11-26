import Foundation
import Intents

class IntentsDonations {
    
    private static let GROUP_IDENTIFIER = "org.OctoPod.Intentions"  // Unique & Global idenfier for all Intents created by this app
    
    static func deleteDonatedIntentions() {
        INInteraction.deleteAll { (error: Error?) in
            if let error = error {
                NSLog("Failed to delete all donated interactions. Error: \(error.localizedDescription)")
            } else {
                NSLog("Donated Interactions deleted")
            }
        }
    }
    
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
                intent.suggestedInvocationPhrase = String(format: NSLocalizedString("Warm up printer bed", comment: ""), printer.name)
            } else {
                intent.suggestedInvocationPhrase = String(format: NSLocalizedString("Cool down printer bed", comment: ""), printer.name)
            }
            
            let interaction = INInteraction(intent: intent, response: nil)
            interaction.identifier = "\(GROUP_IDENTIFIER).Bed"
            interaction.groupIdentifier = GROUP_IDENTIFIER
            
            interaction.donate { (error) in
                if let error = error {
                    NSLog("Interaction donation failed: \(error.localizedDescription)")
                } else {
                    NSLog("Successfully donated interaction")
                }
            }
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
                intent.suggestedInvocationPhrase = String(format: NSLocalizedString("Warm up printer extruder", comment: ""), printer.name)
            } else {
                intent.suggestedInvocationPhrase = String(format: NSLocalizedString("Cool down printer extruder", comment: ""), printer.name)
            }
            
            let interaction = INInteraction(intent: intent, response: nil)
            interaction.identifier = "\(GROUP_IDENTIFIER).Tool"
            interaction.groupIdentifier = GROUP_IDENTIFIER
            
            interaction.donate { (error) in
                if let error = error {
                    NSLog("Interaction donation failed: \(error.localizedDescription)")
                } else {
                    NSLog("Successfully donated interaction")
                }
            }
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
            intent.suggestedInvocationPhrase = String(format: NSLocalizedString("Pause current print job", comment: ""), printer.name)
            
            let interaction = INInteraction(intent: intent, response: nil)
            interaction.identifier = "\(GROUP_IDENTIFIER).Pause"
            interaction.groupIdentifier = GROUP_IDENTIFIER
            
            interaction.donate { (error) in
                if let error = error {
                    NSLog("Interaction donation failed: \(error.localizedDescription)")
                } else {
                    NSLog("Successfully donated interaction")
                }
            }
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
            intent.suggestedInvocationPhrase = String(format: NSLocalizedString("Resume current print job", comment: ""), printer.name)
            
            let interaction = INInteraction(intent: intent, response: nil)
            interaction.identifier = "\(GROUP_IDENTIFIER).Resume"
            interaction.groupIdentifier = GROUP_IDENTIFIER
            
            interaction.donate { (error) in
                if let error = error {
                    NSLog("Interaction donation failed: \(error.localizedDescription)")
                } else {
                    NSLog("Successfully donated interaction")
                }
            }
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
            intent.suggestedInvocationPhrase = String(format: NSLocalizedString("Cancel current print job", comment: ""), printer.name)
            
            let interaction = INInteraction(intent: intent, response: nil)
            interaction.identifier = "\(GROUP_IDENTIFIER).Cancel"
            interaction.groupIdentifier = GROUP_IDENTIFIER
            
            interaction.donate { (error) in
                if let error = error {
                    NSLog("Interaction donation failed: \(error.localizedDescription)")
                } else {
                    NSLog("Successfully donated interaction")
                }
            }
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
            intent.suggestedInvocationPhrase = String(format: NSLocalizedString("Restart current print job", comment: ""), printer.name)
            
            let interaction = INInteraction(intent: intent, response: nil)
            interaction.identifier = "\(GROUP_IDENTIFIER).Restart"
            interaction.groupIdentifier = GROUP_IDENTIFIER
            
            interaction.donate { (error) in
                if let error = error {
                    NSLog("Interaction donation failed: \(error.localizedDescription)")
                } else {
                    NSLog("Successfully donated interaction")
                }
            }
        }
    }
}
