import Foundation
import AVKit

class HLSThumbnailUtil: NSObject {
    let url: URL
    let username: String?
    let password: String?
    let imageOrientation: UIImage.Orientation
    let complete: ((UIImage?) -> Void)
    
    var player: AVPlayer?
    var itemDelegate: AVAssetResourceLoaderDelegate?
    var videOutput: AVPlayerItemVideoOutput?
    
    init(url: URL, imageOrientation: UIImage.Orientation, username: String?, password: String?, complete: @escaping ((UIImage?) -> Void)) {
        self.url = url
        self.username = username
        self.password = password
        self.imageOrientation = imageOrientation
        self.complete = complete
    }
    
    func generate()  {
        // Create AVPlayerItem object
        let asset = AVURLAsset(url: url)

        if let username = username, let password = password {
            itemDelegate = UIUtils.getAVAssetResourceLoaderDelegate(username: username, password: password)
            asset.resourceLoader.setDelegate(itemDelegate, queue:  DispatchQueue.global(qos: .userInitiated))
        }
        
        let playerItem = AVPlayerItem(asset: asset)
        // Register as an observer of the player item's status property
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status ), options: [.old, .new], context: nil)

        let settings = [ String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_24RGB ]
        videOutput = AVPlayerItemVideoOutput(outputSettings: settings)
        playerItem.add(videOutput!)
        
        // Create AVPlayer object
        player = AVPlayer(playerItem: playerItem)
        player?.volume = 0 // Disable audio
        player?.play()

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
                // Play half a second and fetch image
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.fetchImage()
                }
            case .failed:
                NSLog("Player item failed.")
//                if let playerItem = object as? AVPlayerItem, let error = playerItem.error {
//                    NSLog("Player item error: \(error.localizedDescription)")
//                    self.stopPlaying()
//                    // Display error messages
//                    self.errorMessageLabel.text = error.localizedDescription
//                    self.errorMessageLabel.numberOfLines = 2
//                    self.errorURLButton.setTitle(self.cameraURL, for: .normal)
//                    self.errorMessageLabel.isHidden = false
//                    self.errorURLButton.isHidden = false
//                }
                // Execute complete block with no fetched image
                complete(nil)
            case .unknown:
                // Execute complete block with no fetched image
                complete(nil)
            @unknown default:
                // Execute complete block with no fetched image
                complete(nil)
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    fileprivate func fetchImage() {
        // Fetch image that is currently being displayed
        let time = player!.currentTime()

        if let buffer: CVPixelBuffer = videOutput!.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) {
            // Stop player
            player?.pause()
            let ciImage: CIImage = CIImage(cvPixelBuffer: buffer)
            let context: CIContext = CIContext.init(options: nil)
            if let cgImage: CGImage = context.createCGImage(ciImage, from: ciImage.extent) {
                let receivedImage: UIImage
                if imageOrientation != UIImage.Orientation.up {
                    // Rotate image based on requested orientation
                    receivedImage = UIImage(cgImage: cgImage, scale: CGFloat(1.0), orientation: imageOrientation)
                } else {
                    receivedImage = UIImage(cgImage: cgImage)
                }
                
                // Remove observer. This will prevent potential app crashes in case the observer was removed from memory
                if let playerItem = player?.currentItem {
                    playerItem.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status ))
                }

                // Execute complete block with fetched image
                complete(receivedImage)
                return
            }
        }
        // Stop player
        player?.pause()

        // Remove observer. This will prevent potential app crashes in case the observer was removed from memory
        if let playerItem = player?.currentItem {
            playerItem.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status ))
        }

        // Execute complete block with no fetched image
        complete(nil)
    }
}
