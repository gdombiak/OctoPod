import Foundation

protocol SubpanelsVCDelegate : class {
    
    /// Notification when user swiped to another subpanel and transition finished
    /// - parameter index: zero-index of the new SubpanelViewController that is now visible
    func finishedTransitionSubpanel(index: Int)
    
    /// Notification that visibility of tool0 temperature label has changed
    func toolLabelVisibilityChanged()
}
