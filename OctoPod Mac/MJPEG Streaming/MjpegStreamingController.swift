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

import Cocoa

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
    
    open var authenticationHandler: ((URLAuthenticationChallenge) -> (Foundation.URLSession.AuthChallengeDisposition, URLCredential?))?
    open var authenticationFailedHandler: (()->Void)?
    open var didStartLoading: (()->Void)?
    open var didFinishLoading: (()->Void)?
    open var didFinishWithErrors: ((Error)->Void)?
    open var didFinishWithHTTPErrors: ((HTTPURLResponse)->Void)?
    open var didFetchImage: ((NSImage)->Void)?
    open var didRenderImage: ((NSImage)->Void)?
    open var contentURL: URL?
    open var imageView: NSImageView?
   
    public override init() {
        super.init()
        self.session = Foundation.URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
    }

    public convenience init(imageView: NSImageView) {
        self.init()
        self.imageView = imageView
    }
    
    public convenience init(imageView: NSImageView, contentURL: URL) {
        self.init(imageView: imageView)
        self.contentURL = contentURL
    }
    
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
        
        status = .loading
        executeBlock { self.didStartLoading?() }
        
        receivedData = NSMutableData()
        let request = URLRequest(url: url)
        dataTask = session.dataTask(with: request)
        dataTask?.resume()
    }
    
    open func stop(){
        status = .stopped
        dataTask?.cancel()
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
            let receivedImage = NSImage(data: imageData as Data) {
            
            // I'm creating the NSImage before performing didFinishLoading to minimize the interval
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
        }
        
        receivedData = NSMutableData()
        completionHandler(.allow)
    }
    
    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receivedData?.append(data)
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
    
    // MARK: - Private function
    
    fileprivate func executeBlock(block: @escaping () -> Void ) {
        if imageView == nil {
            block()
        } else {
            DispatchQueue.main.async { block() }
        }
    }
}
