import Foundation

// Object that represent the Serial Terminal. It keeps track of the logs that were received
// Logs are cleaned up when connecting to a new printer
class Terminal {
    let MAX_LOG_SIZE = 100
    
    var logs = Array<String>()
    
    // Notification that we connected to OctoPrint via websockets
    func websocketConnected() {
        // Clean up the logs since we are starting from scratch
        logs.removeAll()
    }
    
    // Notification that OctoPrint state has changed. This may include printer status information
    func currentStateUpdated(event: CurrentStateEvent) {
        if let newLogs = event.logs {
            if newLogs.isEmpty {
                // Nothing to do here
                return
            }
            // Make sure that we do not go over the limit of logs we keep in memory
            if logs.count + newLogs.count > MAX_LOG_SIZE {
                let toDeleteCount = logs.count + newLogs.count - MAX_LOG_SIZE
                logs.removeFirst(toDeleteCount)
            }
            
            // Add new logs
            logs.append(contentsOf: newLogs)
        }
    }

    
}
