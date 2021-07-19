import Foundation

class Timelapse {
    /// Name of the timelapse file
    private(set) var name: String
    /// Formatted size of the timelapse file
    private(set) var size: String
    /// Size of the timelapse file in bytes
    private(set) var bytes: Int
    /// Formatted timestamp of the timelapse creation date
    private(set) var date: String
    /// URL for downloading the timelapse
    private(set) var url: String

    init(name: String, size: String, bytes: Int, date: String, url: String) {
        self.name = name
        self.size = size
        self.bytes = bytes
        self.date = date
        self.url = url
    }
}
