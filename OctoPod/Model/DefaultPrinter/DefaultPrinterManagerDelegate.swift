import Foundation

protocol DefaultPrinterManagerDelegate: AnyObject {
    
    /// Notification that a new default printer has been selected. User may have used iPhone app or Apple Watch app
    /// to change default printer
    func defaultPrinterChanged()
}
