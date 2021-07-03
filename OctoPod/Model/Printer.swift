import Foundation
import CoreData

/// A Printer (term used in the UI) actually represents an OctoPrint server
class Printer: NSManagedObject {
    
    /// Unique identifier of this record in CloudKit
    @NSManaged var recordName: String?
    /// Encoded data of the iCloud record
    @NSManaged var recordData: Data?
    /// Flag that indicates if this record needs to be created/updated in CloudKit
    @NSManaged var iCloudUpdate: Bool
    
    /// Raw value of PrinterConnectionType enum
    @NSManaged var connectionType: Int16
    /// Zero-index position of this printer in the list of printers
    @NSManaged var position: Int16
    @NSManaged var name: String
    @NSManaged var hostname: String
    /// path to the webcam. Info discovered via api/settings
    @NSManaged var streamUrl: String?
    @NSManaged var apiKey: String
    @NSManaged var defaultPrinter: Bool
    /// Date when user last modified this settings
    @NSManaged var userModified: Date?

    @NSManaged var username: String?
    @NSManaged var password: String?
    
    /// Show this printer in dashboard of printers. Defauilt is true
    @NSManaged var includeInDashboard: Bool
    /// Some users do not have a camera installed so offer the option to hide camera subpanel
    @NSManaged var hideCamera: Bool

    /// Information configured in OctoPrint -> Appearance to control color of UI
    @NSManaged var color: String?
    
    /// Number of detected tools (extruders). This information is discovered based on reported temperatures or printer profiles
    @NSManaged var toolsNumber: Int16
    /// A printer may have many extruders but a single nozzle (e.g. MMU)
    @NSManaged var sharedNozzle: Bool

    /// Array of Int (bed temperatures from OctoPrint settings)
    @NSManaged var bedTemps: [Int]?
    /// Array of Int (extruder temperatures from OctoPrint settings)
    @NSManaged var extruderTemps: [Int]?

    /// Remember aspect ratio of first camera so UI can adapt to proper aspect ratio
    @NSManaged var firstCameraAspectRatio16_9: Bool
    @NSManaged var sdSupport: Bool
    /// Raw value of UIImageOrientation enum
    @NSManaged var cameraOrientation: Int16
    /// Array that holds URLs to cameras. OctoPrint needs to use MultiCam plugin
    @NSManaged public var multiCameras: Set<MultiCamera>?

    @NSManaged var invertX: Bool  // Control of X is inverted
    @NSManaged var invertY: Bool  // Control of Y is inverted
    @NSManaged var invertZ: Bool  // Control of Z is inverted
    
    // Track if the following plugins are installed and configured
    @NSManaged var psuControlInstalled: Bool
    /// Array of an Array with 2 strings (IP Address, Label)
    @NSManaged var tpLinkSmartplugs: [[String]]?
    /// Array of an Array with 2 strings (IP Address, Label)
    @NSManaged var wemoplugs: [[String]]?
    /// Array of an Array with 2 strings (IP Address, Label)
    @NSManaged var domoticzplugs: [[String]]?
    /// Array of an Array with 2 strings (IP Address, Label)
    @NSManaged var tasmotaplugs: [[String]]?
    /// Track if CancelObjects plugin is installed
    @NSManaged var cancelObjectInstalled: Bool
    /// Comma delimited list of objects that should be ignored (cannot be cancelled)
    @NSManaged var cancelObjectIgnored: String?
    @NSManaged var octopodPluginInstalled: Bool
    /// APNS token that was last registered with this OctoPrint instance
    @NSManaged var notificationToken: String?
    /// APNS notifications will use printer name as title
    @NSManaged var octopodPluginPrinterName: String?
    /// APNS notifications will be sent with the specified language
    @NSManaged var octopodPluginLanguage: String?
    @NSManaged var palette2Installed: Bool
    @NSManaged var palette2AutoConnect: Bool    
    @NSManaged var palette2CanvasInstalled: Bool
    @NSManaged var filamentManagerInstalled: Bool    
    
    // Plugin updates tracking
    /// Date when we can check again for plugin updates
    @NSManaged var pluginsUpdateNextCheck: Date?
    /// Hash of last found updates that user asked to stop showing
    @NSManaged var pluginsUpdateSnooze: String?
    
    @NSManaged public var enclosureInputs: Set<EnclosureInput>?
    @NSManaged public var enclosureOutputs: Set<EnclosureOutput>?

    @NSManaged public var blTouch: BLTouch?

    // MARK: - Properties

    func getStreamPath() -> String {
        if let path = streamUrl {
            return path
        }
        return "/webcam/?action=stream"
    }
    
    /// Returns true if returned getStreamPath() is coming from what OctoPrint reported via /api/settings. False means that it is assumed one
    func isStreamPathFromSettings() -> Bool {
        return streamUrl != nil
    }
    
    /// Returns sorted array of cameras by their position as they were defined in OctoPrint
    func getMultiCameras() -> Array<MultiCamera>? {
        // OctoEverywhere only supports one camera for proxy streaming
        if getPrinterConnectionType() == .octoEverywhere {
            return nil
        }
        if let cameras = multiCameras {
            return cameras.sorted { (l: MultiCamera, r: MultiCamera) -> Bool in
                return l.index_id < r.index_id
            }
        }
        return nil
    }

    func setTPLinkSmartplugs(plugs: [IPPlug]?) {
        if let newPlugs = plugs {
            var newValues: [[String]] = []
            for newPlug in newPlugs {
                newValues.append(encodeIPPlug(newPlug))
            }
            tpLinkSmartplugs = newValues
        } else {
            tpLinkSmartplugs = nil
        }
    }
    
    func getTPLinkSmartplugs() -> [IPPlug]? {
        if let plugs = tpLinkSmartplugs {
            var result:[IPPlug] = []
            for plug in plugs {
                result.append(decodePlug(encoded: plug))
            }
            return result
        }
        return nil
    }

    func setWemoPlugs(plugs: [IPPlug]?) {
        if let newPlugs = plugs {
            var newValues: [[String]] = []
            for newPlug in newPlugs {
                newValues.append(encodeIPPlug(newPlug))
            }
            wemoplugs = newValues
        } else {
            wemoplugs = nil
        }
    }
    
    func getWemoPlugs() -> [IPPlug]? {
        if let plugs = wemoplugs {
            var result:[IPPlug] = []
            for plug in plugs {
                result.append(decodePlug(encoded: plug))
            }
            return result
        }
        return nil
    }

    func setDomoticzPlugs(plugs: [IPPlug]?) {
        if let newPlugs = plugs {
            var newValues: [[String]] = []
            for newPlug in newPlugs {
                newValues.append(encodeIPPlug(newPlug))
            }
            domoticzplugs = newValues
        } else {
            domoticzplugs = nil
        }
    }
    
    func getDomoticzPlugs() -> [IPPlug]? {
        if let plugs = domoticzplugs {
            var result:[IPPlug] = []
            for plug in plugs {
                result.append(decodePlug(encoded: plug))
            }
            return result
        }
        return nil
    }
    
    func setTasmotaPlugs(plugs: [IPPlug]?) {
        if let newPlugs = plugs {
            var newValues: [[String]] = []
            for newPlug in newPlugs {
                newValues.append(encodeIPPlug(newPlug))
            }
            tasmotaplugs = newValues
        } else {
            tasmotaplugs = nil
        }
    }
    
    func getTasmotaPlugs() -> [IPPlug]? {
        if let plugs = tasmotaplugs {
            var result:[IPPlug] = []
            for plug in plugs {
                result.append(decodePlug(encoded: plug))
            }
            return result
        }
        return nil
    }
    
    /// Returns outputs defined in the enclosure plugin. Only outputs that can be
    /// controlled from OctoPod are returned
    func getEnclosureOutputs() -> Array<EnclosureOutput> {
        var result: Array<EnclosureOutput> = []
        if let outputs = self.enclosureOutputs {
            for output in outputs {
                // Only add supported types of outputs
                if output.type == "regular" || output.type == "pwm" {
                    result.append(output)
                }
            }
        }
        return result
    }
    
    /// Returns "regular" outputs defined in the enclosure plugin. These are switches
    /// that can be turned off or on
    func getEnclosureRegularOutputs() -> Array<EnclosureOutput> {
        var result: Array<EnclosureOutput> = []
        if let outputs = self.enclosureOutputs {
            for output in outputs {
                // Only add regular type of outputs
                if output.type == "regular" {
                    result.append(output)
                }
            }
        }
        return result
    }
    
    /// Return type of connection being used to talk to OctoPrint
    func getPrinterConnectionType() -> PrinterConnectionType {
        return PrinterConnectionType(rawValue: connectionType)!
    }
    
    /// Set type of connection being used to talk to OctoPrint
    func setPrinterConnectionType(connectionType: PrinterConnectionType) {
        self.connectionType = connectionType.rawValue
    }
    
    /// Returns true if HTTP Basic authentication should be preemptive or wait for challenge response header
    func preemptiveAuthentication() -> Bool {
        // Only OctoEverywhere uses preemptive authentication
        return getPrinterConnectionType() == .octoEverywhere
    }
    
    // MARK: - Private functions

    fileprivate func encodeIPPlug(_ newPlug: IPPlug) -> [String] {
        var result = [newPlug.ip, newPlug.label]
        if let idx = newPlug.idx {
            result.append(idx)
        }
        if let username = newPlug.username {
            result.append(username)
        }
        if let password = newPlug.password {
            result.append(password)
        }
        return result
    }
    
    fileprivate func decodePlug(encoded: Array<String>) -> IPPlug {
        let ip = encoded[0]
        let label = encoded[1]
        var idx: String?
        var username: String?
        var password: String?
        if encoded.count > 2 {
            idx = encoded[2]
        }
        if encoded.count > 3 {
            username = encoded[3]
        }
        if encoded.count > 4 {
            password = encoded[4]
        }
        return IPPlug(ip: ip, label: label, idx: idx, username: username, password: password)
    }

}
