import Foundation

protocol OctoPrintPluginsDelegate: class {
    
    // Notification sent by plugin via websockets
    // plugin - identifier of the OctoPrint plugin
    // data - whatever JSON data structure sent by the plugin
    //
    // Example: {data: {isPSUOn: false, hasGPIO: true}, plugin: "psucontrol"}
    func pluginMessage(plugin: String, data: NSDictionary)
}
