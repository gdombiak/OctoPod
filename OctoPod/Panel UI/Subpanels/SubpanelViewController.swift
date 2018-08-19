import Foundation

protocol SubpanelViewController {
    
    // Notification that another OctoPrint server has been selected
    func printerSelectedChanged()

    // Notification that OctoPrint state has changed. This may include printer status information
    func currentStateUpdated(event: CurrentStateEvent)
    
    // Returns the position where this VC should appear in SubpanelsViewController's UIPageViewController
    // SubpanelsViewController's will sort subpanels by this number when being displayed
    func position() -> Int
}
