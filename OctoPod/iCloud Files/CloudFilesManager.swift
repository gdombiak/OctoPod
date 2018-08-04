import Foundation

class CloudFilesManager {
    
    enum Location {
        case OctoPrint
        case SDCard
    }
    
    let octoprintClient: OctoPrintClient!
    
    var containerUrl: URL? {
        // Will return nil if iCloud is not configured in the device
        return FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents")
    }
    
    init(octoprintClient: OctoPrintClient) {
        self.octoprintClient = octoprintClient
        // check for container existence
        if let url = self.containerUrl, !FileManager.default.fileExists(atPath: url.path, isDirectory: nil) {
            // Let's create the folder in case it is missing (should already be there)
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            }
            catch {
                NSLog("Error creating iCloud Drive Container: \(error.localizedDescription)")
            }
        }
    }
}
