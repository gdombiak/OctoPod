import UIKit
import AVFoundation
import AVKit

class CameraHLSEmbeddedViewController: CameraEmbeddedViewController {
    @IBOutlet weak var playerView: MyAVPlayerView!
    @IBOutlet weak var pipButton: UIButton!
    
    var player: AVPlayer?
    var itemDelegate: AVAssetResourceLoaderDelegate?
    
    var pipPossibleObservation: NSKeyValueObservation?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Configure PIP button
        let startImage = AVPictureInPictureController.pictureInPictureButtonStartImage(compatibleWith: nil)
        pipButton.setImage(startImage, for: .normal)
        pipButton.isHidden = true
    }
    
    @IBAction func togglePictureInPictureMode(_ sender: UIButton) {
        camerasViewController?.togglePictureInPictureMode()
        if camerasViewController?.userStartedPIP ?? false {
            pipButton.setImage(AVPictureInPictureController.pictureInPictureButtonStopImage(compatibleWith: nil), for: .normal)
        } else {
            pipButton.setImage(AVPictureInPictureController.pictureInPictureButtonStartImage(compatibleWith: nil), for: .normal)
        }
    }

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
    
    fileprivate func setupPictureInPicture() {
        // Ensure PiP is supported by current device.
        if camerasViewController?.offerPIP ?? false && AVPictureInPictureController.isPictureInPictureSupported() {
            let castedLayer = playerView.layer as! AVPlayerLayer
         
            let callback = {
                DispatchQueue.main.async {
                    self.pipButton.setImage(AVPictureInPictureController.pictureInPictureButtonStartImage(compatibleWith: nil), for: .normal)
                }
            }
            // Create a new controller, passing the reference to the AVPlayerLayer.
            camerasViewController?.initPictureInPictureController(playerLayer: castedLayer, pipClosedCallback: callback)
            // Observe whether using PiP mode is possible in the current context; for example, when the system is displaying
            // an active FaceTime window. By observing this property, you can determine when it’s appropriate to change the
            // enabled state of your PiP button.
            pipPossibleObservation = camerasViewController?.pictureInPictureController!.observe(\AVPictureInPictureController.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] _, change in
                // Update the PiP button's enabled state.
                self?.pipButton.isHidden = !(change.newValue ?? false)
            }
        } else {
            // PiP isn't supported by the current device. Disable the PiP button.
            pipButton.isHidden = true
        }
    }

    // MARK: - Abstract methods
    
    override func renderPrinter(printer: Printer, url: URL) {
        setupPictureInPicture()

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
        
        // Mute video if requested
        player?.isMuted = muteVideo
        
        // Add player to AVPlayerLayer
        let castedLayer = playerView.layer as! AVPlayerLayer
        castedLayer.player = player
        
        // Notify aspect ratio to use for this camera
        if let camera = printer.getMultiCameras()?[safeIndex: cameraIndex] {
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
        if !(camerasViewController?.userStartedPIP ?? false) {
            self.player?.pause()

            // Stop listening to events since player is going away. App will crash if KVO notification goes to a zombie object
            player?.currentItem?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status ))

            let castedLayer = self.playerView.layer as! AVPlayerLayer
            castedLayer.player = nil
            self.player = nil
            self.itemDelegate = nil
        }
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

