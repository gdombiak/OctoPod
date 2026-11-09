import Foundation

class UIUtils {

    /// Return estimated completion date based on number of estimated seconds to completion
    static func secondsToETA(seconds: Int) -> String {
        WatchTimeFormatting.eta(seconds: seconds)
    }

    static func isHLS(url: String) -> Bool {
        WatchTimeFormatting.isHLS(url: url)
    }
}
