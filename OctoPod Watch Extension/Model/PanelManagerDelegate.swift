import Foundation

protocol PanelManagerDelegate: class {

    /// Notification that new panel information has been received
    func panelInfoUpdate(printerName: String, panelInfo: [String : Any])
    
    /// Notification that we need to update complications. Originated from iOS App
    func updateComplications(printerName: String, printerState: String, completion: Double)
}
