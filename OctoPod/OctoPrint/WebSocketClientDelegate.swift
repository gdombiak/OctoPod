import Foundation

// Listener that reacts to changes in the websocket connection and received updates via websocket
protocol WebSocketClientDelegate: class {
    
    // Notification that OctoPrint state has changed. This may include printer status information
    func currentStateUpdated(event: CurrentStateEvent)
    
    // Notifcation that OctoPrint's settings has changed
    func octoPrintSettingsUpdated()

    // Notification sent when websockets got connected
    func websocketConnected()
    
    // Notification sent when websockets got disconnected due to an error (or failed to connect)
    func websocketConnectionFailed(error: Error)
}
