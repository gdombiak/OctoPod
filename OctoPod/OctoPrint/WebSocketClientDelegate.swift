import Foundation

// Listener that reacts to changes in the websocket connection and received updates via websocket
protocol WebSocketClientDelegate: class {
    
    // Notification that OctoPrint state has changed. This may include printer status information
    func currentStateUpdated(event: CurrentStateEvent)
    
    // Notification that contains history of temperatures. This information is received once after
    // websocket connection was established. #currentStateUpdated contains new temps after this event
    func historyTemp(history: Array<TempHistory.Temp>)
    
    // Notifcation that OctoPrint's settings has changed
    func octoPrintSettingsUpdated()

    // Notification sent by plugin via websockets
    // plugin - identifier of the OctoPrint plugin
    // data - whatever JSON data structure sent by the plugin
    //
    // Example: {data: {isPSUOn: false, hasGPIO: true}, plugin: "psucontrol"}
    func pluginMessage(plugin: String, data: NSDictionary)

    // Notification sent when websockets got connected
    func websocketConnected()
    
    // Notification sent when websockets got disconnected due to an error (or failed to connect)
    func websocketConnectionFailed(error: Error)
}
