//
//  MjpegStreamingController.swift
//  MjpegStreamingKit
//
//  Created by Stefano Vettor on 28/03/16.
//  Copyright © 2016 Stefano Vettor. All rights reserved.
//
//  Modified for better error handling
//  Modified to allow image rotation
//

import UIKit

open class MjpegStreamingController: NSObject, URLSessionDataDelegate {
    
    fileprivate enum Status {
        case stopped
        case loading
        case playing
    }
    
    fileprivate var receivedData: NSMutableData?
    fileprivate var dataTask: URLSessionDataTask?
    fileprivate var session: Foundation.URLSession!
    fileprivate var status: Status = .stopped
    fileprivate var headers: [String:String]?
    
    open var authorizationHeader: String? // Only used when doing HTTP Basic preemptive
    open var authenticationHandler: ((URLAuthenticationChallenge) -> (Foundation.URLSession.AuthChallengeDisposition, URLCredential?))?
    open var authenticationFailedHandler: (()->Void)?
    open var didStartLoading: (()->Void)?
    open var didFinishLoading: (()->Void)?
    open var didFinishWithErrors: ((Error)->Void)?
    open var didFinishWithHTTPErrors: ((HTTPURLResponse)->Void)?
    open var didFetchImage: ((UIImage)->Void)?
    open var didRenderImage: ((UIImage)->Void)?
    open var didReceiveJSON: ((NSDictionary)->Void)?
    open var contentURL: URL?
    open var imageView: UIImageView?
    open var imageOrientation: UIImage.Orientation?
    open var timeoutInterval: TimeInterval = 15.0 // Set timeout to 15 seconds (used to be 60)
    
    private var parsingJson = false

    public override init() {
        super.init()
        self.session = Foundation.URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
    }

    public convenience init(imageView: UIImageView) {
        self.init()
        self.imageView = imageView
    }
    
//    public convenience init(imageView: UIImageView, contentURL: URL) {
//        self.init(imageView: imageView)
//        self.contentURL = contentURL
//    }
    
    deinit {
        dataTask?.cancel()
    }
    
    open func play(url: URL){
        if status == .playing || status == .loading {
            stop()
        }
        contentURL = url
        play()
    }
    
    open func play() {
        guard let url = contentURL , status == .stopped else {
            return
        }
        
        parsingJson = false
        status = .loading
        executeBlock { self.didStartLoading?() }
        
        receivedData = NSMutableData()
        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: timeoutInterval)
        if let auth = authorizationHeader {
            request.addValue(auth, forHTTPHeaderField: "Authorization")
        }
        // In case some reverse proxy is severing the long-lived connections, let's specify that we want to keep the connection alive
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        if let headers = self.headers {
            for (key, value) in headers {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }
        dataTask = session.dataTask(with: request)
        dataTask?.resume()
    }
    
    open func stop(){
        status = .stopped
        dataTask?.cancel()
    }
    
    open func destroy() {
        dataTask?.cancel()
        // Cancel session so URL session and other objects get released
        session.invalidateAndCancel()
        
        receivedData = nil
        dataTask = nil
        session = nil
        
        // Basic cleanup. Probably wouldn't cause any issues
        authenticationHandler = nil
        authenticationFailedHandler = nil
        didStartLoading = nil
        didFinishLoading = nil
        didFinishWithErrors = nil
        didFinishWithHTTPErrors = nil
        didFetchImage = nil
        didRenderImage = nil
        didReceiveJSON = nil
        imageView = nil
    }
    
    // MARK: - NSURLSessionDataDelegate
    
    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let httpResponse =  response as? HTTPURLResponse, let httpErrorHandler = didFinishWithHTTPErrors {
            if httpResponse.statusCode == 404 ||  httpResponse.statusCode > 500 {
                httpErrorHandler(httpResponse)
                return
            }
        }
        if let imageData = receivedData , imageData.length > 0,
            var receivedImage = UIImage(data: imageData as Data) {
            if let orientation = imageOrientation, let cgImage = receivedImage.cgImage, orientation != UIImage.Orientation.up {
                // Rotate image based on requested orientation
                receivedImage = UIImage(cgImage: cgImage, scale: CGFloat(1.0), orientation: orientation)
            }
            // I'm creating the UIImage before performing didFinishLoading to minimize the interval
            // between the actions done by didFinishLoading and the appearance of the first image
            var firstTimeImage = false
            if status == .loading {
                firstTimeImage = true
                status = .playing
                executeBlock { self.didFinishLoading?() }
            }
            
            executeBlock {
                self.imageView?.image = receivedImage
                self.didFetchImage?(receivedImage)
            }
            
            if firstTimeImage {
                executeBlock { self.didRenderImage?(receivedImage) }
            }
        } else if let httpResponse = response as? HTTPURLResponse, let contentType = httpResponse.allHeaderFields["Content-Type"] as? String {
            parsingJson = "application/json" == contentType && httpResponse.statusCode == 200
        }
        
        receivedData = NSMutableData()
        completionHandler(.allow)
    }
    
    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if parsingJson {
            // Parse returned JSON
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: [.mutableLeaves, .mutableContainers]) as? NSDictionary {
                        didReceiveJSON?(json)
                    }
                }
                catch let err as NSError {
                    NSLog("Error parsing JSON rendering camera. Error: \(err)")
                }
        } else {
            receivedData?.append(data)
        }
    }
    
    // MARK: - NSURLSessionTaskDelegate
    
    open func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
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
    
    public func setHeaders(headers: String?) {
        if self.headers == nil {
            if let headers = URLUtils.parseHeaders(headers: headers) {
                self.headers = headers
            }
        }
    }
    
    // MARK: - Private function
    
    fileprivate func executeBlock(block: @escaping () -> Void ) {
        if imageView == nil {
            block()
        } else {
            DispatchQueue.main.async { block() }
        }
    }
}
