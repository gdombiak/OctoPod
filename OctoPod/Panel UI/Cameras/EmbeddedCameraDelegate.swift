import Foundation
import UIKit

protocol EmbeddedCameraDelegate : class {
    
    // Notification when an aspect ratio of image has been detected
    func imageAspectRatio(ratio: CGFloat)

    func startTransitionNewPage()
    
    func finishedTransitionNewPage()

}
