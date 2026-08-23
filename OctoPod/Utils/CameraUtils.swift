import Foundation
import UIKit

class CameraUtils {
    
    /// Singleton instance of this class
    static let shared = CameraUtils()
    
    // We need to keep this as an instance variable so it is not garbage collected and crashes
    // the app since it uses KVO which crashes if observer has been GC'ed
    private var hlsThumbnailGenerator: HLSThumbnailUtil?
    
    private init() {
    }
    
    func renderImage(cameraURL: URL, imageOrientation: UIImage.Orientation, username: String?, password: String?, headers: String?, preemptive: Bool, timeoutInterval: TimeInterval?, completion: @escaping (UIImage?, String?) -> ()) {
        if isHLS(url: cameraURL.absoluteString) {
            // Render image from HLS camera
            renderHLSImage(cameraURL: cameraURL, imageOrientation: imageOrientation, username: username, password: password, headers: headers, completion: completion)
        } else if isTSD(cameraURL: cameraURL) {
            // Obico has its own special logic
            renderTLSImage(cameraURL: cameraURL, imageOrientation: imageOrientation, username: username, password: password, preemptive: preemptive, timeoutInterval: timeoutInterval, completion: completion)
        } else {
            // Render image from classic MJPEG camera
            renderMJPEGImage(cameraURL: cameraURL, imageOrientation: imageOrientation, username: username, password: password, headers: headers, preemptive: preemptive, timeoutInterval: timeoutInterval, completion: completion)
        }
    }
    
    /// Returns true if camera URL is rendering HLS videos
    func isHLS(url: String) -> Bool {
        return url.hasSuffix(".m3u8")
    }
    
    /// Returns true if camera URL is hosted via Obico
    func isTSD(cameraURL: URL) -> Bool {
        if let host = cameraURL.host, host.hasSuffix("thespaghettidetective.com") ||  host.hasSuffix("obico.io") {
            return true
        }
        return false
    }
    
    func absoluteURL(hostname: String, streamUrl: String) -> String {
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

    // MARK: - Private functions
    
    fileprivate func renderMJPEGImage(cameraURL: URL, imageOrientation: UIImage.Orientation, username: String?, password: String?, headers: String?, preemptive: Bool, timeoutInterval: TimeInterval?, completion: @escaping (UIImage?, String?) -> ()) {
        let streamingController = MjpegStreamingController()
        
        if let timeout = timeoutInterval {
            streamingController.timeoutInterval = timeout
        }

        if let username = username, let password = password {
            // User authentication credentials if configured for the printer
            if preemptive {
                streamingController.authorizationHeader = HTTPClient.authBasicHeader(username: username, password: password)
            } else {
                streamingController.authenticationHandler = { challenge in
                    let credential = URLCredential(user: username, password: password, persistence: .forSession)
                    return (.useCredential, credential)
                }
            }
        }
        
        streamingController.setHeaders(headers: headers)
                
        streamingController.authenticationFailedHandler = {
            let message = NSLocalizedString("Authentication failed", comment: "HTTP authentication failed")
            completion(nil, message)
        }

        streamingController.didFinishWithErrors = { error in
            completion(nil, error.localizedDescription)
        }
        
        streamingController.didFinishWithHTTPErrors = { httpResponse in
            let message: String
            if httpResponse.statusCode == 609 {
                message = NSLocalizedString("OctoEverywhere: Webcam Limit Exceeded", comment: "Error message from OctoEverywhere")
            } else {
                // We got a 404 or some 5XX error
                message = String(format: NSLocalizedString("HTTP Request error", comment: "HTTP Request error info"), httpResponse.statusCode)
            }
            completion(nil, message)
        }

        streamingController.didRenderImage = { (image: UIImage) in
            // Stop loading next jpeg image (MJPEG is a stream of jpegs)
            streamingController.stop()
            completion(image, nil)
        }

        streamingController.imageOrientation = imageOrientation
        // Get first image and then stop streaming next images
        streamingController.play(url: cameraURL)
    }
    
    fileprivate func renderHLSImage(cameraURL: URL, imageOrientation: UIImage.Orientation, username: String?, password: String?, headers: String?, completion: @escaping (UIImage?, String?) -> ()) {
        hlsThumbnailGenerator = HLSThumbnailUtil(url: cameraURL, imageOrientation: imageOrientation, username: username, password: password, headers: headers) { (image: UIImage?) in
            if let image = image {
                // Execute completion block when done
                completion(image, nil)
            } else {
                // Execute completion block when done
                completion(nil, "No thumbnail generated")
            }
        }
        hlsThumbnailGenerator!.generate()
    }

    fileprivate func renderTLSImage(cameraURL: URL, imageOrientation: UIImage.Orientation, username: String?, password: String?, preemptive: Bool, timeoutInterval: TimeInterval?, completion: @escaping (UIImage?, String?) -> ()) {
        
        struct TSDSnapshotResponse: Codable {
            let snapshot: String?
        }
        
        if let username = username, let password = password {
            var urlRequest = URLRequest(url: cameraURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: timeoutInterval ?? 5.0)
            urlRequest.setValue(HTTPClient.authBasicHeader(username: username, password: password), forHTTPHeaderField: "Authorization")
            URLSession.shared.dataTask(with: urlRequest) { (data: Data?, response: URLResponse?, error: Error?) in
                if let response = response as? HTTPURLResponse, let data = data {
                    if response.statusCode == 200 {
                        do {
                            let snapshotResponse = try JSONDecoder().decode(TSDSnapshotResponse.self, from: data)
                            if let snapshotURL = snapshotResponse.snapshot, let imageURL = URL(string: snapshotURL) {
                                // Fetch and display Image from returned URL
                                self.fetchTLSImage(imageURL: imageURL, imageOrientation: imageOrientation, timeoutInterval: timeoutInterval, completion: completion)
                            } else {
                                completion(nil, NSLocalizedString("Obico Is Not Watching", comment: "Obico Is Not Watching"))
                            }
                        } catch let error {
                            completion(nil, error.localizedDescription)
                        }
                    } else if response.statusCode == 401 {
                        completion(nil, NSLocalizedString("Authentication failed", comment: "HTTP authentication failed"))
                    } else {
                        completion(nil, String(format: NSLocalizedString("HTTP Request error", comment: "HTTP Request error info"), response.statusCode))
                    }
                }
            }.resume()
        }
    }

    fileprivate func fetchTLSImage(imageURL: URL, imageOrientation: UIImage.Orientation, timeoutInterval: TimeInterval?, completion: @escaping (UIImage?, String?) -> ()) {
        let imageURLRequest = URLRequest(url: imageURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 5.0)
        URLSession.shared.dataTask(with: imageURLRequest) { (data: Data?, response: URLResponse?, error: Error?) in
            if let imageData = data , imageData.count > 0, var receivedImage = UIImage(data: imageData) {
                if let cgImage = receivedImage.cgImage, imageOrientation != UIImage.Orientation.up {
                    // Rotate image based on requested orientation
                    receivedImage = UIImage(cgImage: cgImage, scale: CGFloat(1.0), orientation: imageOrientation)
                }
                completion(receivedImage, nil)
            } else if let error = error {
                completion(nil, error.localizedDescription)
            }
        }.resume()
    }
}

#if os(iOS)
/// Camera fullscreen is a landscape session. Physical device orientation is
/// independent and only used for the status overlay.
enum CameraFullscreenSession {
    static func supportedInterfaceOrientations(
        userInterfaceIdiom: UIUserInterfaceIdiom,
        isFullscreen: Bool,
        canEnforceLandscapeSession: Bool,
        fallback: UIInterfaceOrientationMask
    ) -> UIInterfaceOrientationMask {
        if shouldLockInterfaceToLandscapeRight(
            userInterfaceIdiom: userInterfaceIdiom,
            isFullscreen: isFullscreen,
            canEnforceLandscapeSession: canEnforceLandscapeSession
        ) {
            return .landscapeRight
        }
        return fallback
    }

    static func preferredInterfaceOrientation(
        userInterfaceIdiom: UIUserInterfaceIdiom,
        isFullscreen: Bool,
        canEnforceLandscapeSession: Bool,
        fallback: UIInterfaceOrientation
    ) -> UIInterfaceOrientation {
        if shouldLockInterfaceToLandscapeRight(
            userInterfaceIdiom: userInterfaceIdiom,
            isFullscreen: isFullscreen,
            canEnforceLandscapeSession: canEnforceLandscapeSession
        ) {
            return .landscapeRight
        }
        return fallback
    }

    /// iPhone always locks while fullscreen. iPad locks only when the scene can
    /// legally be landscape-only (full-screen, not Split View / Stage Manager).
    static func shouldLockInterfaceToLandscapeRight(
        userInterfaceIdiom: UIUserInterfaceIdiom,
        isFullscreen: Bool,
        canEnforceLandscapeSession: Bool
    ) -> Bool {
        guard isFullscreen else {
            return false
        }
        if userInterfaceIdiom == .phone {
            return true
        }
        return userInterfaceIdiom == .pad && canEnforceLandscapeSession
    }

    static func canEnforceLandscapeSession(in window: UIWindow?) -> Bool {
        guard let window = window else {
            return false
        }
        if #available(iOS 16.0, *), let scene = window.windowScene {
            return scene.isFullScreen
        }
        let screenSize = window.windowScene?.screen.bounds.size ?? .zero
        return occupiesFullScreen(windowSize: window.bounds.size, screenSize: screenSize)
    }

    static func occupiesFullScreen(windowSize: CGSize, screenSize: CGSize) -> Bool {
        let epsilon: CGFloat = 1.5
        func equal(_ a: CGSize, _ b: CGSize) -> Bool {
            abs(a.width - b.width) < epsilon && abs(a.height - b.height) < epsilon
        }
        return equal(windowSize, screenSize)
            || equal(windowSize, CGSize(width: screenSize.height, height: screenSize.width))
    }

    /// One-shot `requestGeometryUpdate` / iOS 15 `setValue` uses the same policy
    /// as the sticky landscape lock.
    static func shouldForceLandscapeGeometry(
        userInterfaceIdiom: UIUserInterfaceIdiom,
        isFullscreen: Bool,
        canEnforceLandscapeSession: Bool
    ) -> Bool {
        shouldLockInterfaceToLandscapeRight(
            userInterfaceIdiom: userInterfaceIdiom,
            isFullscreen: isFullscreen,
            canEnforceLandscapeSession: canEnforceLandscapeSession
        )
    }
}

/// Which embedded camera should have fullscreen presentation active.
enum CameraFullscreenContainer {
    static func isFullscreenActive(containerFullscreen: Bool, isCurrentCamera: Bool) -> Bool {
        containerFullscreen && isCurrentCamera
    }

    static func camerasWithFullscreenPresentation<ID: Hashable>(
        cameraIDs: [ID],
        currentID: ID?,
        containerFullscreen: Bool
    ) -> Set<ID> {
        guard containerFullscreen, let currentID, cameraIDs.contains(currentID) else {
            return []
        }
        return [currentID]
    }
}
#endif

/// Fullscreen-only presentation helpers for portrait camera images.
/// Detection uses displayed/oriented size, not raw JPEG pixels.
/// Extra 90° CCW is iPhone-only: iPhone fullscreen is a forced-landscape
/// session, while iPad camera presentation follows the interface.
enum CameraFullscreenPresentation {
    static func isPortraitDisplay(_ size: CGSize) -> Bool {
        return size.height > size.width
    }

    /// Extra portrait-image rotation is only for iPhone fullscreen.
    /// iPad keeps the configured/source orientation.
    static func shouldApplyFullscreenPortraitImageRotation(
        userInterfaceIdiom: UIUserInterfaceIdiom,
        isFullscreen: Bool,
        isPortraitDisplay: Bool
    ) -> Bool {
        userInterfaceIdiom == .phone && isFullscreen && isPortraitDisplay
    }

    /// Orientation actually assigned to the stream/image for this presentation.
    /// Always computed from the configured orientation so enter/exit cannot accumulate.
    static func imageOrientationForPresentation(
        configuredOrientation: UIImage.Orientation,
        displayedSize: CGSize,
        isFullscreen: Bool,
        userInterfaceIdiom: UIUserInterfaceIdiom
    ) -> UIImage.Orientation {
        if shouldApplyFullscreenPortraitImageRotation(
            userInterfaceIdiom: userInterfaceIdiom,
            isFullscreen: isFullscreen,
            isPortraitDisplay: isPortraitDisplay(displayedSize)
        ) {
            return orientationByRotating90Counterclockwise(configuredOrientation)
        }
        return configuredOrientation
    }

    /// Displayed size after `UIImage` applies `orientation` to `pixelSize`.
    static func displayedSize(pixelSize: CGSize, orientation: UIImage.Orientation) -> CGSize {
        switch orientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            return CGSize(width: pixelSize.height, height: pixelSize.width)
        default:
            return pixelSize
        }
    }

    /// 90° counterclockwise on the already-displayed image.
    /// Fullscreen still requests landscape geometry; this only chooses the extra
    /// image-orientation direction used so a portrait stream fills that screen.
    static func orientationByRotating90Counterclockwise(_ orientation: UIImage.Orientation) -> UIImage.Orientation {
        switch orientation {
        case .up: return .left
        case .left: return .down
        case .down: return .right
        case .right: return .up
        case .upMirrored: return .leftMirrored
        case .leftMirrored: return .downMirrored
        case .downMirrored: return .rightMirrored
        case .rightMirrored: return .upMirrored
        @unknown default: return orientation
        }
    }

    static func imageByReplacingOrientation(_ image: UIImage, orientation: UIImage.Orientation) -> UIImage {
        guard let cgImage = image.cgImage else {
            return image
        }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: orientation)
    }
}

#if os(iOS)
/// Fullscreen-only print-status overlay placement relative to physical device orientation.
/// Identity is the `UIDeviceOrientation` that matches the actual interface/window orientation
/// (Apple's landscape raw-value inversion: interface `.landscapeRight` ↔ device `.landscapeLeft`).
/// Overlay rotation is identity − physical (UIKit clockwise-positive), not the device rotation itself.
/// iPhone fullscreen locks to `.landscapeRight`, so the no-argument placement API keeps that mapping.
enum CameraFullscreenStatusOverlay {
    enum Corner: Equatable {
        case topRight
        case bottomRight
        case bottomLeft
        case topLeft
    }

    struct Placement: Equatable {
        let rotationRadians: CGFloat
        let corner: Corner
    }

    static func isValidPhysicalOrientation(_ orientation: UIDeviceOrientation) -> Bool {
        switch orientation {
        case .portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight:
            return true
        default:
            return false
        }
    }

    /// Face-up / face-down / unknown keep the last valid physical orientation.
    static func resolvedPhysicalOrientation(_ current: UIDeviceOrientation, lastValid: UIDeviceOrientation) -> UIDeviceOrientation {
        if isValidPhysicalOrientation(current) {
            return current
        }
        return lastValid
    }

    /// The iOS 15 `UIDevice.setValue` landscapeRight force writes raw value 3, which is
    /// `UIDeviceOrientation.landscapeLeft`. iOS 16+ `requestGeometryUpdate` does not.
    static func shouldSuppressLegacyForcedLandscapeArtifact(
        usedLegacyDeviceOrientationForce: Bool,
        lastValidPhysicalOrientation: UIDeviceOrientation
    ) -> Bool {
        guard usedLegacyDeviceOrientationForce else {
            return false
        }
        return lastValidPhysicalOrientation != .landscapeLeft
    }

    /// Device orientation whose "up" matches `interfaceOrientation`'s view-space up.
    /// Landscape names are inverted between the two enums.
    static func deviceOrientationMatching(_ interfaceOrientation: UIInterfaceOrientation) -> UIDeviceOrientation {
        switch interfaceOrientation {
        case .landscapeRight: return .landscapeLeft
        case .landscapeLeft: return .landscapeRight
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        default: return .landscapeLeft
        }
    }

    /// Clockwise radians from physical portrait, matching `UIDeviceOrientation`:
    /// landscapeRight is home-on-left (device rotated clockwise).
    static func clockwiseRadiansFromPortrait(_ orientation: UIDeviceOrientation) -> CGFloat {
        switch orientation {
        case .portrait: return 0
        case .landscapeRight: return .pi / 2
        case .portraitUpsideDown: return .pi
        case .landscapeLeft: return 3 * .pi / 2
        default: return 0
        }
    }

    /// Overlay rotation in UIKit view space (positive is clockwise on screen).
    /// Compensate by identity − physical so text stays world-upright.
    static func overlayRotationRadians(
        physicalOrientation: UIDeviceOrientation,
        interfaceOrientation: UIInterfaceOrientation = .landscapeRight
    ) -> CGFloat {
        let identity = clockwiseRadiansFromPortrait(deviceOrientationMatching(interfaceOrientation))
        let physical = clockwiseRadiansFromPortrait(physicalOrientation)
        return normalizedMinusPiToPi(identity - physical)
    }

    /// Identity physical hold puts the overlay at UI top-right. Rotate that corner
    /// by the overlay compensation so it tracks the user's physical top-right.
    static func cornerByRotatingIdentityTopRight(rotationRadians: CGFloat) -> Corner {
        let quarters = Int((normalizedMinusPiToPi(rotationRadians) / (.pi / 2)).rounded())
        switch quarters {
        case 0: return .topRight
        case -1, 3: return .topLeft
        case 1, -3: return .bottomRight
        default: return .bottomLeft
        }
    }

    static func normalizedMinusPiToPi(_ radians: CGFloat) -> CGFloat {
        var value = radians.truncatingRemainder(dividingBy: 2 * .pi)
        if value <= -.pi {
            value += 2 * .pi
        } else if value > .pi {
            value -= 2 * .pi
        }
        return value
    }

    /// Overlay sits in the user's physical top-right, with text upright for that hold.
    /// Default `interfaceOrientation` is `.landscapeRight` (validated iPhone fullscreen lock).
    static func placement(
        physicalOrientation: UIDeviceOrientation,
        interfaceOrientation: UIInterfaceOrientation = .landscapeRight
    ) -> Placement {
        guard isValidPhysicalOrientation(physicalOrientation) else {
            return Placement(rotationRadians: 0, corner: .topRight)
        }
        let rotation = overlayRotationRadians(
            physicalOrientation: physicalOrientation,
            interfaceOrientation: interfaceOrientation
        )
        return Placement(
            rotationRadians: rotation,
            corner: cornerByRotatingIdentityTopRight(rotationRadians: rotation)
        )
    }

    static func targetPoint(
        in bounds: CGRect,
        safeAreaInsets: UIEdgeInsets,
        corner: Corner,
        topInset: CGFloat,
        sideInset: CGFloat
    ) -> CGPoint {
        switch corner {
        case .topRight:
            return CGPoint(x: bounds.maxX - safeAreaInsets.right - sideInset, y: bounds.minY + safeAreaInsets.top + topInset)
        case .bottomRight:
            return CGPoint(x: bounds.maxX - safeAreaInsets.right - sideInset, y: bounds.maxY - safeAreaInsets.bottom - topInset)
        case .bottomLeft:
            return CGPoint(x: bounds.minX + safeAreaInsets.left + sideInset, y: bounds.maxY - safeAreaInsets.bottom - topInset)
        case .topLeft:
            return CGPoint(x: bounds.minX + safeAreaInsets.left + sideInset, y: bounds.minY + safeAreaInsets.top + topInset)
        }
    }

    /// Center for an overlay whose local top-right should land on `targetTopRight` after rotation.
    static func overlayCenter(size: CGSize, targetTopRight: CGPoint, rotationRadians: CGFloat) -> CGPoint {
        let localTopRightFromCenter = CGPoint(x: size.width / 2, y: -size.height / 2)
        let rotated = localTopRightFromCenter.applying(CGAffineTransform(rotationAngle: rotationRadians))
        return CGPoint(x: targetTopRight.x - rotated.x, y: targetTopRight.y - rotated.y)
    }
}

/// iPad-only physical orientation while the fullscreen interface is landscape-locked.
/// iPhone keeps using `UIDevice.orientation`, which continues to report all four holds.
/// On a physical iPad, `UIDevice.orientation` stays at the locked-landscape match, so gravity is the source.
enum CameraFullscreenPhysicalOrientation {
    /// Physical iPad with device motion. Simulator and iPhone keep `UIDevice.orientation`.
    static func usesGravitySource(
        userInterfaceIdiom: UIUserInterfaceIdiom,
        isDeviceMotionAvailable: Bool,
        isSimulator: Bool
    ) -> Bool {
        userInterfaceIdiom == .pad && isDeviceMotionAvailable && !isSimulator
    }

    /// Fall back to `UIDevice.orientation` once if motion fails before any usable sample.
    static func shouldFallbackToDeviceOrientation(
        motionError: Bool,
        receivedUsableMotion: Bool,
        alreadyFellBack: Bool
    ) -> Bool {
        motionError && !receivedUsableMotion && !alreadyFellBack
    }

    /// Core Motion gravity is in device coordinates (portrait: +x right, +y up, +z toward user).
    /// Face-up / face-down when Z dominates; otherwise the larger of |X| and |Y|.
    static func orientation(gravityX: Double, gravityY: Double, gravityZ: Double) -> UIDeviceOrientation {
        let absX = abs(gravityX)
        let absY = abs(gravityY)
        let absZ = abs(gravityZ)
        if absZ > max(absX, absY) && absZ > 0.75 {
            return gravityZ > 0 ? .faceDown : .faceUp
        }
        if absY >= absX {
            return gravityY < 0 ? .portrait : .portraitUpsideDown
        }
        return gravityX < 0 ? .landscapeLeft : .landscapeRight
    }
}
#endif
