import Foundation

class PrinterUtils {

    /// Returns true if event indicates that printer is operational. It may or may not be printing
    static func isOperational(event: CurrentStateEvent?) -> Bool {
        if let operational = event?.operational {
            return operational
        }
        return false
    }

    /// Returns true if event indicates that printer is operational and is currently running a print job. Printer could be pausing or paused and still return true
    static func isPrinting(event: CurrentStateEvent?) -> Bool {
        if let operational = event?.operational, let progress = event?.progressCompletion {
            return operational && progress > 0 && progress < 100
        }
        return false
    }
}
