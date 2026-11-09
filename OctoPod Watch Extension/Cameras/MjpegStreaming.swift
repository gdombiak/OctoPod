import WatchKit

class MjpegStreaming: NSObject, URLSessionDataDelegate {
    
    fileprivate enum Status {
        case stopped
        case loading
        case playing
    }
    
    fileprivate var receivedData: NSMutableData?
    fileprivate var dataTask: URLSessionDataTask?
    fileprivate var session: Foundation.URLSession!
    fileprivate var status: Status = .stopped
    fileprivate var playback = WatchCameraPlayback()
    fileprivate let callbackLock = NSLock()
    
    var authenticationHandler: ((URLAuthenticationChallenge) -> (Foundation.URLSession.AuthChallengeDisposition, URLCredential?))?
    var authenticationFailedHandler: (()->Void)?
    var didStartLoading: (()->Void)?
    var didFinishLoading: (()->Void)?
    var didFinishWithErrors: ((Error)->Void)?
    var didFinishWithHTTPErrors: ((HTTPURLResponse)->Void)?
    var contentURL: URL?
    var didRendered: (()->Void)?

    var imageView: WKInterfaceImage?
    var imageHandler: ((UIImage) -> Void)?
    var imageOrientation: UIImage.Orientation?
    
    public init(imageView: WKInterfaceImage) {
        self.imageView = imageView
        super.init()
        configureSession()
    }

    public init(imageHandler: @escaping (UIImage) -> Void) {
        self.imageHandler = imageHandler
        super.init()
        configureSession()
    }

    private func configureSession() {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = Foundation.URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }
    
    deinit {
        dataTask?.cancel()
        session.invalidateAndCancel()
    }
    
    /// Starts a stream. The closure runs before the task resumes and receives the token that
    /// identifies this playback. A previous stream is invalidated first so its queued callbacks
    /// cannot update the UI or stop this one. `stopIfCurrent` does not invalidate that token:
    /// the first frame is already queued and still belongs to this playback.
    func play(url: URL, configure: ((Int) -> Void)? = nil) {
        callbackLock.lock()
        let active = status == .playing || status == .loading
        callbackLock.unlock()
        if active {
            stop()
        }

        callbackLock.lock()
        contentURL = url
        guard status == .stopped else {
            callbackLock.unlock()
            return
        }
        status = .loading
        let token = playback.token
        receivedData = NSMutableData()
        // Handlers are installed before the task exists. The closure must not call back into the stream.
        configure?(token)
        let start = didStartLoading
        callbackLock.unlock()
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isCurrentPlayback(token) else {
                return
            }
            start?()
        }

        let task = session.dataTask(with: URLRequest(url: url))
        callbackLock.lock()
        let startTask = status == .loading && playback.isCurrent(token)
        if startTask {
            dataTask = task
        }
        callbackLock.unlock()
        if startTask {
            task.resume()
        } else {
            task.cancel()
        }
    }
    
    func isCurrentPlayback(_ token: Int) -> Bool {
        callbackLock.lock()
        defer { callbackLock.unlock() }
        return playback.isCurrent(token)
    }

    /// User switch, refresh, or disappear. Invalidates the token before cancelling the task.
    func stop() {
        callbackLock.lock()
        playback.invalidate()
        let task = takeTaskLocked()
        callbackLock.unlock()
        task?.cancel()
    }

    /// First-frame teardown. Does nothing when `token` belongs to a stream that has already been replaced.
    func stopIfCurrent(token: Int) {
        callbackLock.lock()
        guard playback.isCurrent(token) else {
            callbackLock.unlock()
            return
        }
        let task = takeTaskLocked()
        callbackLock.unlock()
        task?.cancel()
    }

    private func takeTaskLocked() -> URLSessionDataTask? {
        status = .stopped
        let task = dataTask
        dataTask = nil
        return task
    }
    
    // MARK: - NSURLSessionDataDelegate
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        let snapshot = callbackSnapshot(for: dataTask)
        guard snapshot.isCurrent else {
            completionHandler(.cancel)
            return
        }
        if let httpResponse = response as? HTTPURLResponse, let httpErrorHandler = snapshot.httpErrorHandler {
            if httpResponse.statusCode == 404 || httpResponse.statusCode > 500 {
                // The session stalls if this completion handler is skipped. .cancel is ignored
                // in didCompleteWithError, so the HTTP message from the handler stays on screen.
                httpErrorHandler(httpResponse)
                completionHandler(.cancel)
                return
            }
        }

        var receivedImage: UIImage?
        if let imageData = snapshot.bufferedImage, imageData.isEmpty == false, var image = UIImage(data: imageData) {
            if let orientation = snapshot.imageOrientation, let cgImage = image.cgImage, orientation != .up {
                image = UIImage(cgImage: cgImage, scale: 1, orientation: orientation)
            }
            receivedImage = image
        }

        callbackLock.lock()
        let stillCurrent = dataTask === self.dataTask && playback.isCurrent(snapshot.token) && status != .stopped
        var shouldFinish = false
        if stillCurrent {
            // The JPEG is the buffer accumulated before this response boundary.
            receivedData = NSMutableData()
            if receivedImage != nil && status == .loading {
                status = .playing
                shouldFinish = true
            }
        }
        callbackLock.unlock()
        guard stillCurrent else {
            completionHandler(.cancel)
            return
        }

        // Capture the closures installed for this playback. A block queued here must not call the
        // closures a newer camera installs, and a stale finish must not stop that newer stream.
        let token = snapshot.token
        let finish = snapshot.finish
        let handler = snapshot.imageHandler
        let rendered = snapshot.rendered
        let view = snapshot.imageView
        if shouldFinish {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.isCurrentPlayback(token) else {
                    return
                }
                finish?()
            }
        }
        if let receivedImage = receivedImage {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.isCurrentPlayback(token) else {
                    return
                }
                view?.setImage(receivedImage)
                handler?(receivedImage)
                rendered?()
            }
        }

        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        callbackLock.lock()
        if dataTask === self.dataTask && status != .stopped {
            receivedData?.append(data)
        }
        callbackLock.unlock()
    }
    
    // MARK: - NSURLSessionTaskDelegate
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let snapshot = callbackSnapshot(for: task)
        guard snapshot.isCurrent else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        var credential: URLCredential?
        var disposition: Foundation.URLSession.AuthChallengeDisposition = .performDefaultHandling
        
        if challenge.previousFailureCount > 0 {
            snapshot.authenticationFailedHandler?()
            completionHandler(.cancelAuthenticationChallenge, nil)
        } else {
            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
                if let trust = challenge.protectionSpace.serverTrust {
                    credential = URLCredential(trust: trust)
                    disposition = .useCredential
                }
            } else if let onAuthentication = snapshot.authenticationHandler {
                (disposition, credential) = onAuthentication(challenge)
            }
            
            completionHandler(disposition, credential)
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let snapshot = callbackSnapshot(for: task)
        guard snapshot.isCurrent, let error = error else {
            return
        }
        if (error as NSError).code == NSURLErrorCancelled {
            // View disappeared or the user switched cameras and cancelled this task.
            return
        }
        snapshot.errorHandler?(error)
    }

    private struct CallbackSnapshot {
        var token: Int
        var isCurrent: Bool
        var bufferedImage: Data?
        var imageOrientation: UIImage.Orientation?
        var imageView: WKInterfaceImage?
        var imageHandler: ((UIImage) -> Void)?
        var finish: (() -> Void)?
        var rendered: (() -> Void)?
        var httpErrorHandler: ((HTTPURLResponse) -> Void)?
        var errorHandler: ((Error) -> Void)?
        var authenticationHandler: ((URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?))?
        var authenticationFailedHandler: (() -> Void)?
    }

    private func callbackSnapshot(for task: URLSessionTask) -> CallbackSnapshot {
        callbackLock.lock()
        defer { callbackLock.unlock() }
        let token = playback.token
        let isCurrent = task === dataTask && status != .stopped && playback.isCurrent(token)
        var bufferedImage: Data?
        if isCurrent, let imageData = receivedData, imageData.length > 0 {
            bufferedImage = Data(bytes: imageData.bytes, count: imageData.length)
        }
        return CallbackSnapshot(
            token: token,
            isCurrent: isCurrent,
            bufferedImage: bufferedImage,
            imageOrientation: imageOrientation,
            imageView: imageView,
            imageHandler: imageHandler,
            finish: didFinishLoading,
            rendered: didRendered,
            httpErrorHandler: didFinishWithHTTPErrors,
            errorHandler: didFinishWithErrors,
            authenticationHandler: authenticationHandler,
            authenticationFailedHandler: authenticationFailedHandler
        )
    }
}

//extension UIImage{
//    
//    func resizeImageWith(newSize: CGSize) -> UIImage {
//        let horizontalRatio = newSize.width / size.width
//        let verticalRatio = newSize.height / size.height
//        
//        let ratio = max(horizontalRatio, verticalRatio)
//        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
//        UIGraphicsBeginImageContextWithOptions(newSize, true, 0)
//        draw(in: CGRect(origin: CGPoint(x: 0, y: 0), size: newSize))
//        let newImage = UIGraphicsGetImageFromCurrentImageContext()
//        UIGraphicsEndImageContext()
//        return newImage!
//    }
//}
