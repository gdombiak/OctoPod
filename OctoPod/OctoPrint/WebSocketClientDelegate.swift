import Foundation

// Listener that view controllers should use to react to changes in the printer status
protocol WebSocketClientDelegate {
    
    // Notification that the current state of the printer has changed
    func currentStateUpdated(event: CurrentStateEvent)

    // Notification sent when websockets got connected
    func websocketConnected()
    
    // Notification sent when websockets got disconnected due to an error (or failed to connect)
    func websocketConnectionFailed(error: Error)
}
