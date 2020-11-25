import UIKit
import AVFoundation

class CameraHLSEmbeddedViewController: CameraEmbeddedViewController {
    @IBOutlet weak var playerView: MyAVPlayerView!
    
    var player: AVPlayer?
    var itemDelegate: AVAssetResourceLoaderDelegate?
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(AVPlayerItem.status) {
            let status: AVPlayerItem.Status
            
            // Get the status change from the change dictionary
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItem.Status(rawValue: statusNumber.intValue)!
            } else {
                status = .unknown
            }
            
            // Switch over the status
            switch status {
            case .readyToPlay:
                break
            case .failed:
                NSLog("Player item failed.")
                if let playerItem = object as? AVPlayerItem, let error = playerItem.error {
                    NSLog("Player item error: \(error.localizedDescription)")
                    self.stopPlaying()
                    // Display error messages
                    self.errorMessageLabel.text = error.localizedDescription
                    self.errorMessageLabel.numberOfLines = 2
                    self.errorURLButton.setTitle(self.cameraURL, for: .normal)
                    self.errorMessageLabel.isHidden = false
                    self.errorURLButton.isHidden = false
                }
            case .unknown:
                NSLog("Player item is not yet ready.")
            @unknown default:
                NSLog("Unkown status: \(status)")
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    // MARK: - Abstract methods
    
    override func renderPrinter(printer: Printer, url: URL) {
        // Create AVPlayerItem object
        let asset = AVURLAsset(url: url)
        
        if let username = printer.username, let password = printer.password {
            itemDelegate = UIUtils.getAVAssetResourceLoaderDelegate(username: username, password: password)
            asset.resourceLoader.setDelegate(itemDelegate, queue:  DispatchQueue.global(qos: .userInitiated))
        }
        
        let playerItem = AVPlayerItem(asset: asset)
        // Register as an observer of the player item's status property
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status ), options: [.old, .new], context: nil)
        
        // Create AVPlayer object
        player = AVPlayer(playerItem: playerItem)
        
        // Add player to AVPlayerLayer
        let castedLayer = playerView.layer as! AVPlayerLayer
        castedLayer.player = player
        
        // Notify aspect ratio to use for this camera
        if let camera = printer.getMultiCameras()?[cameraIndex] {
            let ratio = camera.streamRatio == "16:9" ? CGFloat(0.5625) : CGFloat(0.75)
            cameraViewDelegate?.imageAspectRatio(cameraIndex: cameraIndex, ratio: ratio)
        } else {
            let ratio = printer.firstCameraAspectRatio16_9 ? CGFloat(0.5625) : CGFloat(0.75)
            cameraViewDelegate?.imageAspectRatio(cameraIndex: cameraIndex, ratio: ratio)
        }
        
        // Play Video
        player!.play()
    }
    
    override func setCameraOrientation(newOrientation: UIImage.Orientation) {
        DispatchQueue.main.async {
            switch newOrientation {
            case .up:
                // Go back to normal
                self.playerView.transform = CGAffineTransform(scaleX: 1, y: 1)
            case .upMirrored:
                // Flip webcam horizontally
                self.playerView.transform = CGAffineTransform(scaleX: -1, y: 1)
            case .downMirrored:
                // Flip webcam vertically
                self.playerView.transform = CGAffineTransform(scaleX: 1, y: -1)
            case .left:
                // Rotate webcam 90 degrees counter clockwise
                self.playerView.transform = CGAffineTransform(rotationAngle: CGFloat((270 * Double.pi)/180))
            case .down:
                // Flip webcam horizontally AND Flip webcam vertically
                self.playerView.transform = CGAffineTransform(scaleX: -1, y: -1)
            case .leftMirrored:
                // Flip webcam horizontally AND Rotate webcam 90 degrees counter clockwise
                let flip = CGAffineTransform(scaleX: -1, y: 1)
                self.playerView.transform = flip.concatenating(CGAffineTransform(rotationAngle: CGFloat((270 * Double.pi)/180)))
            case .rightMirrored:
                // Flip webcam vertically AND Rotate webcam 90 degrees counter clockwise
                let flip = CGAffineTransform(scaleX: 1, y: -1)
                self.playerView.transform = flip.concatenating(CGAffineTransform(rotationAngle: CGFloat((270 * Double.pi)/180)))
            case .right:
                // Flip webcam horizontally AND Flip webcam vertically AND Rotate webcam 90 degrees counter clockwise
                let flip = CGAffineTransform(scaleX: -1, y: -1)
                self.playerView.transform = flip.concatenating(CGAffineTransform(rotationAngle: CGFloat((270 * Double.pi)/180)))
            @unknown default:
                NSLog("Unkown flip webcam orientation: \(newOrientation)")
            }
        }
    }
    
    override func stopPlaying() {
        self.player?.pause()
        let castedLayer = self.playerView.layer as! AVPlayerLayer
        castedLayer.player = nil
        self.player = nil
        self.itemDelegate = nil
    }
    
    override func gestureView() -> UIView {
        return playerView
    }
}

/// Use Custom View that uses AVPlayerLayer as layer so constraints are applied automatically
/// Player will resize automatically as View changes size
class MyAVPlayerView: UIView {
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
}

