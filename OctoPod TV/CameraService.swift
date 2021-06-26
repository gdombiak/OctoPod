import Foundation
import UIKit
import AVKit
import SwiftUI

struct Camera {
    var index: Int
    var url: String
    var orientation: UIImage.Orientation
    var streamRatio: CGFloat
}

class CameraService: ObservableObject {
    @Published var image: UIImage?
    @Published var imageRatio: CGFloat?
    @Published var errorMessage: String?
    @Published var hasNext: Bool = false
    @Published var hasPrevious: Bool = false
    
    private var streamingController: MjpegStreamingController?
    @Published var player: AVPlayer?
    @Published var detailedPlayer: AVPlayer?
    @Published var avPlayerEffect3D1: (angle: Angle, axis: (x: CGFloat, y: CGFloat, z: CGFloat))?
    @Published var avPlayerEffect3D2: (angle: Angle, axis: (x: CGFloat, y: CGFloat, z: CGFloat))?
    @Published var avPlayerEffect: Angle?
    private var itemDelegate: AVAssetResourceLoaderDelegate?

    private var cameras: Array<Camera> = Array()
    private var cameraIndex = 0
    private var playing = false
    private var playingInDetailedView = false
    
    private var username: String?
    private var password: String?
    private var preemptiveAuthentication: Bool = false
    private var isStreamPathFromSettings: Bool = true
    
    /// Render next camera
    func renderNext() {
        renderCamera(index: cameraIndex + 1)
    }

    /// Render previous camera
    func renderPrevious() {
        renderCamera(index: cameraIndex - 1)
    }

    // MARK: - Connection handling

    func connectToServer(printer: Printer) {
        if playing {
            return
        }
        username = printer.username
        password = printer.password
        preemptiveAuthentication = printer.preemptiveAuthentication()
        isStreamPathFromSettings = printer.isStreamPathFromSettings()
        
        initCameras(printer: printer)
        
        // Start rendering the last selected camera
        renderCamera(index: cameraIndex)
    }
    
    func disconnectFromServer() {
        streamingController?.stop()
        player?.pause()
        detailedPlayer?.pause()
        playing = false
    }

    // MARK: - Notifications

    /// Notification that the camera service is being used by another view
    func changedView(detailed: Bool) {
        // AVPlayer cannot be used in 2 views so we need to stop the current one
        // and create a new one
        if let _ = player, let _ = detailedPlayer {
            if detailed {
                playingInDetailedView = true
            } else {
                playingInDetailedView = false
            }
            renderCamera(index: cameraIndex)
        }
    }

    // MARK: - Private functions

    fileprivate func prepareForMJPEGRendering() {
        streamingController = MjpegStreamingController()
        // User authentication credentials if configured for the printer
        if let username = username, let password = password {
            if preemptiveAuthentication {
                streamingController?.authorizationHeader = HTTPClient.authBasicHeader(username: username, password: password)
            } else {
                // Handle user authentication if webcam is configured this way (I hope people are being careful and doing this)
                streamingController!.authenticationHandler = { challenge in
                    let credential = URLCredential(user: username, password: password, persistence: .forSession)
                    return (.useCredential, credential)
                }
            }
        }
        
        streamingController!.authenticationFailedHandler = {
            DispatchQueue.main.async {
                self.image = nil
                // Display error messages
                self.errorMessage = NSLocalizedString("Authentication failed", comment: "HTTP authentication failed")
            }
        }
        
        streamingController!.didFinishWithErrors = { error in
            DispatchQueue.main.async {
                self.image = nil
                // Display error messages
                self.errorMessage = error.localizedDescription
            }
        }
        
        streamingController!.didFinishWithHTTPErrors = { httpResponse in
            // We got a 404 or some 5XX error
            DispatchQueue.main.async {
                self.image = nil
                // Display error messages
                if httpResponse.statusCode == 503 && !self.isStreamPathFromSettings {
                    // If URL to camera was not returned via /api/settings and
                    // we got a 503 to the best guessed URL then show "no camera" error message
                    self.errorMessage = NSLocalizedString("No camera", comment: "No camera was found")
                } else {
                    self.errorMessage = String(format: NSLocalizedString("HTTP Request error", comment: "HTTP Request error info"), httpResponse.statusCode)
                }
            }
        }
        
        streamingController!.didFetchImage = { (image: UIImage) in
            DispatchQueue.main.async {
                // Notify that we got our first image and we know its ratio
                self.image = image
                self.imageRatio = image.size.height / image.size.width
            }
        }
        
        streamingController!.didFinishLoading = {
            DispatchQueue.main.async {
                // Hide error messages since an image will be rendered (so that means that it worked!)
                self.errorMessage = nil
            }
        }
    }
    
    fileprivate func prepareForHLSRendering(url: URL) {
        // Create AVPlayerItem object
        let asset = AVURLAsset(url: url)
        
        if let username = username, let password = password {
            itemDelegate = UIUtils.getAVAssetResourceLoaderDelegate(username: username, password: password)
            asset.resourceLoader.setDelegate(itemDelegate, queue:  DispatchQueue.global(qos: .userInitiated))
        }
        
        let playerItem = AVPlayerItem(asset: asset)
        // Register as an observer of the player item's status property
//        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status ), options: [.old, .new], context: nil)
        
        // Set proper image ratio
        self.imageRatio = cameras[cameraIndex].streamRatio

        // Create AVPlayer object
        player = AVPlayer(playerItem: playerItem)
        // Disable volume by default
        player?.isMuted = true
        
        // Create another AVPlayer object to be used in detailed view
        // Same AVPlayer cannot be used by 2 views
        detailedPlayer = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        // Disable volume by default
        detailedPlayer?.isMuted = true
    }

    /// Stops rendering any previous URL and starts rendering the requested camera
    /// Needs to be called from main thread
    fileprivate func renderCamera(index: Int) {
        cameraIndex = index
        hasNext = cameras.count > index + 1
        hasPrevious = index > 0

        if let url = URL(string: cameras[index].url.trimmingCharacters(in: .whitespaces)) {
            let imageOrientation = cameras[index].orientation

            // Stop any video since it will be replaced with a new one
            streamingController?.stop()
            player?.pause()
            detailedPlayer?.pause()

            if UIUtils.isHLS(url: url.absoluteString) {
                // Clean up any previous MJPEG config
                streamingController = nil
                image = nil
                prepareForHLSRendering(url: url)
                
                updateAVPlayerOrientation(orientation: imageOrientation)
                
                if playingInDetailedView {
                    detailedPlayer?.play()
                    detailedPlayer?.isMuted = false
                } else {
                    player!.play()
                }

            } else {
                // Clean up any previous HLS config
                player = nil
                detailedPlayer = nil
                prepareForMJPEGRendering()

                streamingController!.imageOrientation = imageOrientation
                streamingController!.play(url: url)
            }
            playing = true
        } else {
            // Camera URL was not valid (e.g. url string contains characters that are illegal in a URL, or is an empty string)
            self.errorMessage = NSLocalizedString("Invalid camera URL", comment: "URL of camera is invalid")
        }
    }
    
    fileprivate func updateAVPlayerOrientation(orientation: UIImage.Orientation) {
        switch orientation {
        case .up:
            // Go back to normal
            avPlayerEffect3D1 = (Angle(degrees: 0), (x: 0, y: 0, z: 0))
            avPlayerEffect3D2 = (Angle(degrees: 0), (x: 0, y: 0, z: 0))
            avPlayerEffect = Angle(degrees: 0)
        case .upMirrored:
            // Flip webcam horizontally
            avPlayerEffect3D1 = (Angle(degrees: 180), (x: 0, y: 1, z: 0))
            avPlayerEffect3D2 = (Angle(degrees: 0), (x: 0, y: 0, z: 0))
            avPlayerEffect = Angle(degrees: 0)
        case .downMirrored:
            // Flip webcam vertically
            avPlayerEffect3D1 = (Angle(degrees: 180), (x: 1, y: 0, z: 0))
            avPlayerEffect3D2 = (Angle(degrees: 0), (x: 0, y: 0, z: 0))
            avPlayerEffect = Angle(degrees: 0)
        case .left:
            // Rotate webcam 90 degrees counter clockwise
            avPlayerEffect3D1 = (Angle(degrees: 0), (x: 0, y: 0, z: 0))
            avPlayerEffect3D2 = (Angle(degrees: 0), (x: 0, y: 0, z: 0))
            avPlayerEffect = Angle(degrees: -90)
        case .down:
            // Flip webcam horizontally AND Flip webcam vertically
            avPlayerEffect3D1 = (Angle(degrees: 180), (x: 0, y: 1, z: 0))
            avPlayerEffect3D2 = (Angle(degrees: 180), (x: 1, y: 0, z: 0))
            avPlayerEffect = Angle(degrees: 0)
        case .leftMirrored:
            // Flip webcam horizontally AND Rotate webcam 90 degrees counter clockwise
            avPlayerEffect3D1 = (Angle(degrees: 180), (x: 0, y: 1, z: 0))
            avPlayerEffect3D2 = (Angle(degrees: 0), (x: 0, y: 0, z: 0))
            avPlayerEffect = Angle(degrees: -90)
        case .rightMirrored:
            // Flip webcam vertically AND Rotate webcam 90 degrees counter clockwise
            avPlayerEffect3D1 = (Angle(degrees: 180), (x: 1, y: 0, z: 0))
            avPlayerEffect3D2 = (Angle(degrees: 0), (x: 0, y: 0, z: 0))
            avPlayerEffect = Angle(degrees: -90)
        case .right:
            // Flip webcam horizontally AND Flip webcam vertically AND Rotate webcam 90 degrees counter clockwise
            avPlayerEffect3D1 = (Angle(degrees: 180), (x: 0, y: 1, z: 0))
            avPlayerEffect3D2 = (Angle(degrees: 180), (x: 1, y: 0, z: 0))
            avPlayerEffect = Angle(degrees: -90)
        @unknown default:
            NSLog("Unkown flip webcam orientation: \(orientation)")
            // Assume up
            avPlayerEffect3D1 = (Angle(degrees: 0), (x: 0, y: 0, z: 0))
            avPlayerEffect3D2 = (Angle(degrees: 0), (x: 0, y: 0, z: 0))
            avPlayerEffect = Angle(degrees: 0)
        }
    }
    
    /// Discover and store number of cameras, their URL and image orientation
    fileprivate func initCameras(printer: Printer) {
        cameras = Array()
        
        if let multiCameras = printer.getMultiCameras() {
            // MultiCam plugin is installed so show all cameras
            var index = 0
            for multiCamera in multiCameras {
                var cameraOrientation: UIImage.Orientation
                var cameraURL: String
                let url = multiCamera.cameraURL
                if url == printer.getStreamPath() {
                    // This is camera hosted by OctoPrint so respect orientation
                    cameraURL = octoPrintCameraAbsoluteUrl(hostname: printer.hostname, streamUrl: url)
                    cameraOrientation = UIImage.Orientation(rawValue: Int(printer.cameraOrientation))!
                } else {
                    if url.starts(with: "/") {
                        // Another camera hosted by OctoPrint so build absolute URL
                        cameraURL = octoPrintCameraAbsoluteUrl(hostname: printer.hostname, streamUrl: url)
                    } else {
                        // Use absolute URL to render camera
                        cameraURL = url
                    }
                    // Respect orientation defined by MultiCamera plugin
                    cameraOrientation = UIImage.Orientation(rawValue: Int(multiCamera.cameraOrientation))!
                }
        
                cameras.append(Camera(index: index, url: cameraURL, orientation: cameraOrientation, streamRatio: multiCamera.streamRatio == "16:9" ? CGFloat(0.5625) : CGFloat(0.75)))
                index = index + 1
            }
        }
        if cameras.isEmpty {
            // MultiCam plugin is not installed so just show default camera
            let cameraURL = octoPrintCameraAbsoluteUrl(hostname: printer.hostname, streamUrl: printer.getStreamPath())
            let cameraOrientation = UIImage.Orientation(rawValue: Int(printer.cameraOrientation))!
            cameras.append(Camera(index: 0, url: cameraURL, orientation: cameraOrientation, streamRatio: printer.firstCameraAspectRatio16_9 ? CGFloat(0.5625) : CGFloat(0.75)))
        }
    }

    fileprivate func octoPrintCameraAbsoluteUrl(hostname: String, streamUrl: String) -> String {
        if streamUrl.isEmpty {
            // Should never happen but let's be cautious
            return hostname
        }
        if streamUrl.starts(with: "/") {
            // Build absolute URL from relative URL
            return hostname + streamUrl
        }
        // streamURL is an absolute URL so return it
        return streamUrl
    }
}
