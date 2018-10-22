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
    
    var authenticationHandler: ((URLAuthenticationChallenge) -> (Foundation.URLSession.AuthChallengeDisposition, URLCredential?))?
    var authenticationFailedHandler: (()->Void)?
    var didStartLoading: (()->Void)?
    var didFinishLoading: (()->Void)?
    var didFinishWithErrors: ((Error)->Void)?
    var didFinishWithHTTPErrors: ((HTTPURLResponse)->Void)?
    var contentURL: URL?
    var didRendered: (()->Void)?

    var imageView: WKInterfaceImage!
    var imageOrientation: UIImage.Orientation?
    
    public init(imageView: WKInterfaceImage) {
        self.imageView = imageView
        super.init()
        
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = Foundation.URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }
    
    deinit {
        dataTask?.cancel()
        session.invalidateAndCancel()
    }
    
    func play(url: URL){
        if status == .playing || status == .loading {
            stop()
        }
        contentURL = url
        play()
    }
    
    fileprivate func play() {
        guard let url = contentURL , status == .stopped else {
            return
        }
        
        status = .loading
        DispatchQueue.main.async { self.didStartLoading?() }
        
        receivedData = NSMutableData()
        let request = URLRequest(url: url)
        dataTask = session.dataTask(with: request)
        dataTask?.resume()
    }
    
    func stop(){
        status = .stopped
        dataTask?.cancel()
    }
    
    // MARK: - NSURLSessionDataDelegate
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let httpResponse =  response as? HTTPURLResponse, let httpErrorHandler = didFinishWithHTTPErrors {
            if httpResponse.statusCode == 404 ||  httpResponse.statusCode > 500 {
                httpErrorHandler(httpResponse)
                return
            }
        }
        if let imageData = receivedData, imageData.length > 0, var receivedImage = UIImage(data: imageData as Data) {
            // Resize image to reduce UI workload
//            receivedImage = receivedImage.resizeImageWith(newSize: CGSize(width: 380, height: 470))
            if let orientation = imageOrientation, let cgImage = receivedImage.cgImage {
                // Rotate image based on requested orientation
                receivedImage = UIImage(cgImage: cgImage, scale: CGFloat(1.0), orientation: orientation)
            }
            // I'm creating the UIImage before performing didFinishLoading to minimize the interval
            // between the actions done by didFinishLoading and the appearance of the first image
            if status == .loading {
                status = .playing
                DispatchQueue.main.async { self.didFinishLoading?() }
            }
            
            DispatchQueue.main.async {
                self.imageView.setImage(receivedImage)
                self.didRendered?()
            }
        }
        
        receivedData = NSMutableData()
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receivedData?.append(data)
    }
    
    // MARK: - NSURLSessionTaskDelegate
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        var credential: URLCredential?
        var disposition: Foundation.URLSession.AuthChallengeDisposition = .performDefaultHandling
        
        if challenge.previousFailureCount > 0 {
            // User credentials are incorrect
            if let onAuthenticationFailed = authenticationFailedHandler {
                onAuthenticationFailed()
            }
            // Cancel authentication flow
            completionHandler(Foundation.URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge, nil)
        } else {
            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
                if let trust = challenge.protectionSpace.serverTrust {
                    credential = URLCredential(trust: trust)
                    disposition = .useCredential
                }
            } else if let onAuthentication = authenticationHandler {
                (disposition, credential) = onAuthentication(challenge)
            }
            
            completionHandler(disposition, credential)
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let onError = didFinishWithErrors, let error = error {
            if let nsError = error as NSError? {
                if nsError.code == NSURLErrorCancelled {
                    // Do nothing
                    // Happens when view is disappearing and we cancelled
                    // ongoing HTTP request
                    return
                }
            }
            onError(error)
        }
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
