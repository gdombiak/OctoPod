import Foundation

/// Listener that reacts to changes in OctoPrint server events and also to printer events
protocol OctoPrintClientDelegate: class {
    
    /// Notification that we are about to connect to OctoPrint server
    func notificationAboutToConnectToServer()
 
    /// Notification that the current state of the printer has changed
    /// - Parameter event: Printer status at the moment the event happened
    func printerStateUpdated(event: CurrentStateEvent)
    
    /// Notification that HTTP request failed (connection error, authentication error or unexpect http status code)
    /// - Parameter error: Some error that happened while trying to make the HTTP request
    /// - Parameter response: HTTP response that was received
    func handleConnectionError(error: Error?, response: HTTPURLResponse)

    /// Notification sent when websockets got connected
    func websocketConnected()

    /// Notification sent when websockets got disconnected due to an error (or failed to connect)
    /// - Parameter error: Error that disconnected websocket
    func websocketConnectionFailed(error: Error)

}
