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
    
    var timeoutIntervalForRequest = 10.0
    var timeoutIntervalForResource = 16.0

    var preRequest: (() -> Void)?
    var postRequest: (() -> Void)?

    init(serverURL: String, apiKey: String, username: String?, password: String?) {
        super.init()
        self.serverURL = serverURL
        self.apiKey = apiKey
        self.username = username
        self.password = password
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
            self.postRequest?()
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
        self.preRequest?()
        task.resume()
        session.finishTasksAndInvalidate()
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
            self.postRequest?()
            if let httpRes = response as? HTTPURLResponse {
                callback(httpRes.statusCode == 204, error, httpRes)
            } else {
                callback(false, error, HTTPURLResponse(url: url, statusCode: (error! as NSError).code, httpVersion: nil, headerFields: nil)!)
            }
        })
        self.preRequest?()
        task.resume()
        session.finishTasksAndInvalidate()
    }

    func post(_ service: String, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let url: URL = URL(string: serverURL! + service) {            
            // Get session with the provided configuration
            let session = Foundation.URLSession(configuration: getConfiguration(false), delegate: self, delegateQueue: nil)
            
            // Create background task that will perform the HTTP request
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            // Add API Key header
            request.addValue(apiKey, forHTTPHeaderField: "X-Api-Key")
            let task = session.dataTask(with: request, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) -> Void in
                self.postRequest?()
                if let httpRes = response as? HTTPURLResponse {
                    callback(httpRes.statusCode == 204, error, httpRes)
                } else {
                    callback(false, error, HTTPURLResponse(url: url, statusCode: (error! as NSError).code, httpVersion: nil, headerFields: nil)!)
                }
            })
            self.preRequest?()
            task.resume()
            session.finishTasksAndInvalidate()
        } else {
            NSLog("POST not possible. Invalid URL found. Server: \(serverURL!). Service: \(service)")
            if let serverURL = URL(string: serverURL!) {
                if let response = HTTPURLResponse(url: serverURL, statusCode: 404, httpVersion: nil, headerFields: nil) {
                    callback(false, nil, response)
                }
            }
        }
    }
    
    func post(_ service: String, json: NSObject, expected: Int, callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        if let url: URL = URL(string: serverURL! + service) {
            requestWithBody(url, verb: "POST", expected: expected, json: json, callback: callback)
        } else {
            NSLog("POST not possible. Invalid URL found. Server: \(serverURL!). Service: \(service)")
            if let serverURL = URL(string: serverURL!) {
                if let response = HTTPURLResponse(url: serverURL, statusCode: 404, httpVersion: nil, headerFields: nil) {
                    callback(nil, nil, response)
                }
            }
        }
    }
    
    func patch(_ service: String, json: NSObject, expected: Int, callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        if let url: URL = URL(string: serverURL! + service) {
            requestWithBody(url, verb: "PATCH", expected: expected, json: json, callback: callback)
        } else {
            NSLog("PATCH not possible. Invalid URL found. Server: \(serverURL!). Service: \(service)")
            if let serverURL = URL(string: serverURL!) {
                if let response = HTTPURLResponse(url: serverURL, statusCode: 404, httpVersion: nil, headerFields: nil) {
                    callback(nil, nil, response)
                }
            }
        }
    }
    
    func upload(_ service: String, parameters: [String: String]?, filename: String, fileContent: Data, expected: Int, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        let url: URL = URL(string: serverURL! + service)!

        // Get session with the provided configuration
        let session = Foundation.URLSession(configuration: getConfiguration(false), delegate: self, delegateQueue: nil)
        
        // Create background task that will perform the HTTP request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Set multipart boundary
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        // Add API Key header
        request.addValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        // Create multipart that includes file
        request.httpBody = createMultiPartBody(parameters: parameters, boundary: boundary, data: fileContent, mimeType: "application/octet-stream", filename: filename)
        // Send request
        let task = session.dataTask(with: request, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) -> Void in
            self.postRequest?()
            if let httpRes = response as? HTTPURLResponse {
                callback(httpRes.statusCode == 201, error, httpRes)
            } else {
                callback(false, error, HTTPURLResponse(url: url, statusCode: (error! as NSError).code, httpVersion: nil, headerFields: nil)!)
            }
        })
        self.preRequest?()
        task.resume()
        session.finishTasksAndInvalidate()
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
                self.postRequest?()
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
            self.preRequest?()
            task.resume()
            session.finishTasksAndInvalidate()
        } catch let error as NSError {
            err = error
            // Fail to convert NSObject into JSON
            callback(nil, err, HTTPURLResponse(url: url, statusCode: 400, httpVersion: nil, headerFields: nil)!)
        }
    }

    fileprivate func createMultiPartBody(parameters: [String: String]?,
                                boundary: String,
                                data: Data,
                                mimeType: String,
                                filename: String) -> Data {
        var body = Data()
        
        let boundaryPrefix = "--\(boundary)\r\n"
        
        if let params = parameters {
            for (key, value) in params {
                body.append(Data(boundaryPrefix.utf8))
                body.append(Data("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".utf8))
                body.append(Data("\(value)\r\n".utf8))
            }
        }
        
        body.append(Data(boundaryPrefix.utf8))
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".utf8))
        body.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n".utf8))
        body.append(Data("--".appending(boundary.appending("--")).utf8))
        
        return body
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
        config.timeoutIntervalForRequest = timeoutIntervalForRequest
        // Timeout to receive data
        config.timeoutIntervalForResource = timeoutIntervalForResource
        return config
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        if challenge.previousFailureCount > 0 {
            NSLog("Alert Please check the credential")
            completionHandler(Foundation.URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge, nil)
        } else {
            let credential = URLCredential(user: self.username ?? "", password: self.password ?? "", persistence: .forSession)
            completionHandler(Foundation.URLSession.AuthChallengeDisposition.useCredential, credential)
        }
    }
}
