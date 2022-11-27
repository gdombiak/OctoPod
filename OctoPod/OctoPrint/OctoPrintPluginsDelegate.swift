import Foundation

protocol OctoPrintPluginsDelegate: AnyObject {
    
    /// Notification sent by plugin via websockets
    /// - parameter plugin: identifier of the OctoPrint plugin
    /// - parameter data: whatever JSON data structure sent by the plugin
    ///
    /// Example: {data: {isPSUOn: false, hasGPIO: true}, plugin: "psucontrol"}
    func pluginMessage(plugin: String, data: NSDictionary)
}
