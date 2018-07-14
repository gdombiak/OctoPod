import Foundation
import UIKit   // Used for network indicator in the UI

// Basic HTTP Client that offers support for basic HTTP verbs.
// Authentication (user/password) is supported in case a reverse proxy
// is configured properly in front of the OctoPrint server.
// Requests will include the 'X-Api-Key' header that will be processed by
// the OctoPrint server.
class HTTPClient: NSObject, URLSessionTaskDelegate {
    var serverURL: String!
    var apiKey: String!
    var username: String?
    var password: String?

    init(printer: Printer) {
        super.init()
        serverURL = printer.hostname
        apiKey = printer.apiKey
        username = printer.username
        password = printer.password
    }
    
    // MARK: HTTP operations (GET/POST/PUT/DELETE)

    func get(_ service: String, callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        let url: URL = URL(string: serverURL + service)!
        
        // Get session with the provided configuration
        let session = Foundation.URLSession(configuration: getConfiguration(false), delegate: self, delegateQueue: nil)
        
        // Create background task that will perform the HTTP request
        var request = URLRequest(url: url)
        // Add API Key header
        request.addValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        let task = session.dataTask(with: request, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) -> Void in
            DispatchQueue.main.async(execute: { () -> Void in UIApplication.shared.isNetworkActivityIndicatorVisible = false })
            if let httpRes = response as? HTTPURLResponse {
                if error != nil {
                    callback(nil, error, httpRes)
                } else {
                    if httpRes.statusCode == 200 {
                        // Parse string into JSON object
                        let result = String(data: data!, encoding: String.Encoding.utf8)!
                        do {
                            let json = try JSONSerialization.jsonObject(with: result.data(using: String.Encoding.utf8)!, options: [.mutableLeaves, .mutableContainers]) as? NSObject
                            callback(json, nil, httpRes)
                        }
                        catch let err as NSError {
                            callback(nil, err, httpRes)
                        }
                    } else {
                        callback(nil, nil, httpRes)
                    }
                }
            } else {
                callback(nil, error, HTTPURLResponse(url: url, statusCode: (error! as NSError).code, httpVersion: nil, headerFields: nil)!)
            }
        }) 
        DispatchQueue.main.async(execute: { () -> Void in UIApplication.shared.isNetworkActivityIndicatorVisible = true })
        task.resume()
    }
    
    func delete(_ service: String, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        let url: URL = URL(string: serverURL + service)!
        
        // Get session with the provided configuration
        let session = Foundation.URLSession(configuration: getConfiguration(false), delegate: self, delegateQueue: nil)
        
        // Create background task that will perform the HTTP request
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        // Add API Key header
        request.addValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        let task = session.dataTask(with: request, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) -> Void in
            DispatchQueue.main.async(execute: { () -> Void in UIApplication.shared.isNetworkActivityIndicatorVisible = false })
            if let httpRes = response as? HTTPURLResponse {
                callback(httpRes.statusCode == 204, error, httpRes)
            } else {
                callback(false, error, HTTPURLResponse(url: url, statusCode: (error! as NSError).code, httpVersion: nil, headerFields: nil)!)
            }
        })
        DispatchQueue.main.async(execute: { () -> Void in UIApplication.shared.isNetworkActivityIndicatorVisible = true })
        task.resume()
    }

    func post(_ service: String, json: NSObject, expected: Int, callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        let url: URL = URL(string: serverURL! + service)!
        requestWithBody(url, verb: "POST", expected: expected, json: json, callback: callback)
    }
    
    // MARK: Private functions
    
    fileprivate func requestWithBody(_ url: URL, verb: String, expected: Int, json: NSObject?, callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        
        // Get session with the provided configuration
        let session = Foundation.URLSession(configuration: getConfiguration(false), delegate: self, delegateQueue: nil)
        
        var request = URLRequest(url: url)
        // Add API Key header
        request.addValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.httpMethod = verb
        var err: NSError?
        do {
            if let data = json {
                let postBody = try JSONSerialization.data(withJSONObject: data, options:JSONSerialization.WritingOptions(rawValue: 0))
                request.httpBody = postBody
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
            }
            
            // Create background task that will perform the HTTP request
            let task = session.dataTask(with: request, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) -> Void in
                DispatchQueue.main.async(execute: { () -> Void in UIApplication.shared.isNetworkActivityIndicatorVisible = false })
                if let httpRes = response as? HTTPURLResponse {
                    if error != nil {
                        callback(nil, error, httpRes)
                    } else {
                        if httpRes.statusCode == expected {
                            if expected == 204 {
                                // No content so nothing to parse
                                callback(nil, nil, httpRes)
                                return
                            }
                            // Parse string into JSON object
                            let result = String(data: data!, encoding: String.Encoding.utf8)!
                            do {
                                let json = try JSONSerialization.jsonObject(with: result.data(using: String.Encoding.utf8)!, options: [.mutableLeaves, .mutableContainers]) as? NSObject
                                callback(json, nil, httpRes)
                            } catch let err as NSError {
                                callback(nil, err, httpRes)
                            }
                            
                        } else {
                            callback(nil, nil, httpRes)
                        }
                    }
                } else {
                    callback(nil, error, HTTPURLResponse(url: url, statusCode: (error! as NSError).code, httpVersion: nil, headerFields: nil)!)
                }
            }) 
            DispatchQueue.main.async(execute: { () -> Void in UIApplication.shared.isNetworkActivityIndicatorVisible = true })
            task.resume()
        } catch let error as NSError {
            err = error
            // Fail to convert NSObject into JSON
            callback(nil, err, HTTPURLResponse(url: url, statusCode: 400, httpVersion: nil, headerFields: nil)!)
        }
    }

    fileprivate func getConfiguration(_ preemptive: Bool) -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        if preemptive && username != nil && password != nil {
            let userPasswordString = username! + ":" + password!
            let userPasswordData = userPasswordString.data(using: String.Encoding.utf8)
            let base64EncodedCredential = userPasswordData!.base64EncodedString(options: [])
            let authString = "Basic \(base64EncodedCredential)"
            config.httpAdditionalHeaders = ["Authorization" : authString]
        }
        // Timeout to start transmitting
        config.timeoutIntervalForRequest = 10.0;
        // Timeout to receive data
        config.timeoutIntervalForResource = 16.0;
        return config
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        if challenge.previousFailureCount > 0 {
            NSLog("Alert Please check the credential")
            completionHandler(Foundation.URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge, nil)
        } else {
            let credential = URLCredential(user: self.username!, password: self.password!, persistence: .forSession)
            completionHandler(Foundation.URLSession.AuthChallengeDisposition.useCredential, credential)
        }
    }
}
