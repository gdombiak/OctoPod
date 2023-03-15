import Foundation
import ActivityKit

struct PrintJobAttributes: ActivityAttributes {
    public typealias PrintJobStatus = ContentState

    // Information that can change
    public struct ContentState: Codable, Hashable {
        // !!! MAKE SURE TO UPDATE APNS PUSH NOTIFICATION SERVICE IF YOU CHANGE FIELDS BELOW !!!!
        var printerStatus: String
        var completion: Int
        var printTimeLeft: Int
    }

    // Information that is static (i.e. does not change)
    var urlSafePrinter: String
    var printerName: String
    var printFileName: String
    var pluginInstalled: Bool
}
