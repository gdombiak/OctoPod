import Foundation
import UIKit

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

    static func isValidURL(inputURL: String) -> Bool {
        let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        if let match = detector.firstMatch(in: inputURL, options: [], range: NSRange(location: 0, length: inputURL.utf16.count)), let url = URL(string: inputURL) {
            // it is a link, if the match covers the whole string
            if match.range.length == inputURL.utf16.count, let scheme = url.scheme, let hostname = url.host {
                // Do a few more tests to confirm this is a valid URL
                return UIApplication.shared.canOpenURL(url) && scheme.starts(with: "http") && !((hostname == "http" || hostname == "https") && url.path.starts(with: "//"))
            } else {
                return false
            }
        } else {
            return false
        }
    }

}
