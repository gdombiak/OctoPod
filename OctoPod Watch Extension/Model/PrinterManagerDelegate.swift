import Foundation
import UIKit

protocol PrinterManagerDelegate: class {
    
    /// Notification that list of printers has changed. Could be that new
    /// ones were added, or updated or deleted. Change was pushed from iOS app
    /// to the Apple Watch
    func printersChanged()
    
    /// Notification that selected printer has changed due to a remote change
    /// Remote change could be from iPhone or iPad. Local changes do not trigger
    /// this notification
    func defaultPrinterChanged(newDefault: [String: Any]?)

    /// Notification that an image has been received from a received file
    /// If image is nil then that means that there was an error reading
    /// the file to get the image
    func imageReceived(image: UIImage?, cameraId: String)
}
