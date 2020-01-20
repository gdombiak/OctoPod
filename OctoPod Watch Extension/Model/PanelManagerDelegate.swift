import Foundation

protocol PanelManagerDelegate: class {

    /// Notification that new panel information has been received
    func panelInfoUpdate(printerName: String, panelInfo: [String : Any])
    
    /// Notification that we need to update complications. Originated from iOS App
    func updateComplications(printerName: String, printerState: String, completion: Double, palette2LastPing: String?, palette2LastVariation: String?, palette2MaxVariation: String?)
    
    /// Notification that user using iOS app changed the content that complications should display
    func updateComplicationsContentType(contentType: String)
}

// Make everything optional so implementors of this protocol are not forced to implement everything
extension PanelManagerDelegate {
    func updateComplicationsContentType(contentType: String) {
    }
}
