import Foundation
import UIKit

protocol CameraViewDelegate : class {
    
    // Notification when an aspect ratio of image has been detected
    func imageAspectRatio(cameraIndex: Int, ratio: CGFloat)

    // Notification that user swiped to another camera and transition started
    func startTransitionNewPage()
    
    // Notification that user swiped to another camera and transition finished
    func finishedTransitionNewPage()

}
