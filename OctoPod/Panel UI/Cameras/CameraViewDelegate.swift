import Foundation
import UIKit

protocol CameraViewDelegate : AnyObject {
    
    /// Notification when an aspect ratio of image has been detected
    func imageAspectRatio(cameraIndex: Int, ratio: CGFloat)

    /// Notification that user swiped to another camera and transition started
    func startTransitionNewPage()
    
    /// Notification that user swiped to another camera and transition finished
    func finishedTransitionNewPage()

}

extension CameraViewDelegate {

    func imageAspectRatio(cameraIndex: Int, ratio: CGFloat) {}

    func startTransitionNewPage() {}
    
    func finishedTransitionNewPage() {}
}
