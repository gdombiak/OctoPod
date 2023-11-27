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
    var headers: [String:String]?
    var preemptive: Bool! // Use HTTP Basic preemptive authentication or wait for WWW-Authenticate Response Header
    
    var timeoutIntervalForRequest = 10.0
    var timeoutIntervalForResource = 16.0

    var preRequest: (() -> Void)?
    var postRequest: (() -> Void)?

    init(serverURL: String, apiKey: String, username: String?, password: String?, headers: String?, preemptive: Bool = false) {
        super.init()
        self.serverURL = serverURL.hasSuffix("/") ? String(serverURL.dropLast()) : serverURL // Fix in case stored printer has invalid URL due to a bug that is now fixed
        self.apiKey = apiKey
        self.username = username
        self.password = password
        self.headers = URLUtils.parseHeaders(headers: headers)
        self.preemptive = preemptive
    }
    
    // MARK: HTTP operations (GET/POST/PUT/DELETE)

    func get(_ service: String, callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        getData(service) { (data: Data?, error: Error?, response: HTTPURLResponse) in
            if let data = data {
                // Parse string into JSON object
                let result = String(data: data, encoding: String.Encoding.utf8)!
                do {
                    let json = try JSONSerialization.jsonObject(with: result.data(using: String.Encoding.utf8)!, options: [.mutableLeaves, .mutableContainers]) as? NSObject
                    callback(json, nil, response)
                }
                catch let err as NSError {
                    callback(nil, err, response)
                }
            } else {
                callback(nil, error, response)
            }
        }
    }

    func getData(_ service: String, callback: @escaping (Data?, Error?, HTTPURLResponse) -> Void) {
        if let url: URL = buildURL(service) {
            // Get session with the provided configuration
            let session = Foundation.URLSession(configuration: getConfiguration(), delegate: self, delegateQueue: nil)

            // Create background task that will perform the HTTP request
            var request = URLRequest(url: url)
            // Add API Key header
            addApiKey(&request)
            let task = session.dataTask(with: request, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) -> Void in
                self.postRequest?()
                if let httpRes = response as? HTTPURLResponse {
                    if error != nil {
                        callback(nil, error, httpRes)
                    } else {
                        if httpRes.statusCode == 200 {
                            callback( data!, nil, httpRes)
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
        } else {
            NSLog("GET ignored. Invalid URL found. Server: \(serverURL!). Service: \(service)")
            callback(nil, NSError(domain: "", code: 400, userInfo: nil), HTTPURLResponse(url: URL(string: "/")!, statusCode: 400, httpVersion: nil, headerFields: nil)!)
        }
    }
    
    func download(_ service: String, progress: @escaping (Int64, Int64) -> Void, completion: @escaping (Data?, Error?) -> Void) {
        if let url: URL = buildURL(service) {
            // Get session with the provided configuration
            let delegate = WrappedDownloadTaskDelegate(httpClient: self, progress: progress, completion: completion)
            let configuration = getConfiguration()
            // Increate timeouts
            configuration.timeoutIntervalForResource = 90
            let session = Foundation.URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
            
            // Create background task that will perform the HTTP request
            var request = URLRequest(url: url)
            // Add API Key header
            addApiKey(&request)
            let task = session.downloadTask(with: request)
            self.preRequest?()
            task.resume()
            session.finishTasksAndInvalidate()
        } else {
            NSLog("GET ignored. Invalid URL found. Server: \(serverURL!). Service: \(service)")
            completion(nil, NSError(domain: "", code: 400, userInfo: nil))
        }
    }
    
    func delete(_ service: String, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let url: URL = buildURL(service) {
            // Get session with the provided configuration
            let session = Foundation.URLSession(configuration: getConfiguration(), delegate: self, delegateQueue: nil)
            
            // Create background task that will perform the HTTP request
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            // Add API Key header
            addApiKey(&request)
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
            NSLog("DELETE ignored. Invalid URL found. Server: \(serverURL!). Service: \(service)")
            callback(false, NSError(domain: "", code: 400, userInfo: nil), HTTPURLResponse(url: URL(string: "/")!, statusCode: 400, httpVersion: nil, headerFields: nil)!)
        }
    }

    func post(_ service: String, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let url: URL = buildURL(service) {
            // Get session with the provided configuration
            let session = Foundation.URLSession(configuration: getConfiguration(), delegate: self, delegateQueue: nil)
            
            // Create background task that will perform the HTTP request
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            // Add API Key header
            addApiKey(&request)
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
        if let url: URL = buildURL(service) {
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
        if let url: URL = buildURL(service) {
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
    
    func put(_ service: String, json: NSObject, expected: Int, callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        if let url: URL = buildURL(service) {
            requestWithBody(url, verb: "PUT", expected: expected, json: json, callback: callback)
        } else {
            NSLog("PUT not possible. Invalid URL found. Server: \(serverURL!). Service: \(service)")
            if let serverURL = URL(string: serverURL!) {
                if let response = HTTPURLResponse(url: serverURL, statusCode: 404, httpVersion: nil, headerFields: nil) {
                    callback(nil, nil, response)
                }
            }
        }
    }
    
    func upload(_ service: String, parameters: [String: String]?, filename: String, fileContent: Data, expected: Int, callback: @escaping (Bool, Error?, HTTPURLResponse) -> Void) {
        if let url: URL = buildURL(service) {
            // Get session with the provided configuration
            let session = Foundation.URLSession(configuration: getConfiguration(), delegate: self, delegateQueue: nil)
            
            // Create background task that will perform the HTTP request
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            // Set multipart boundary
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            // Add API Key header
            addApiKey(&request)
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
        } else {
            NSLog("POST ignored. Invalid URL found. Server: \(serverURL!). Service: \(service)")
            callback(false, NSError(domain: "", code: 400, userInfo: nil), HTTPURLResponse(url: URL(string: "/")!, statusCode: 400, httpVersion: nil, headerFields: nil)!)
        }
    }
    
    // MARK: Private functions
    
    fileprivate func requestWithBody(_ url: URL, verb: String, expected: Int, json: NSObject?, callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        
        // Get session with the provided configuration
        let session = Foundation.URLSession(configuration: getConfiguration(), delegate: self, delegateQueue: nil)
        
        var request = URLRequest(url: url)
        // Add API Key header
        addApiKey(&request)
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
    
    class func authBasicHeader(username: String, password: String) -> String {
        let userPasswordString = username + ":" + password
        let userPasswordData = userPasswordString.data(using: String.Encoding.utf8)
        let base64EncodedCredential = userPasswordData!.base64EncodedString(options: [])
        return "Basic \(base64EncodedCredential)"
    }
    
    fileprivate func getConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        if let username = username, let password = password, preemptive {
            config.httpAdditionalHeaders = ["Authorization" : HTTPClient.authBasicHeader(username: username, password: password)]
        }
        if let headers = headers {
            if config.httpAdditionalHeaders == nil {
                config.httpAdditionalHeaders = headers
            } else {
                config.httpAdditionalHeaders = config.httpAdditionalHeaders?.merging(headers, uniquingKeysWith: { (first, _) in first })
            }
        }
        // Timeout to start transmitting
        config.timeoutIntervalForRequest = timeoutIntervalForRequest
        // Timeout to receive data
        config.timeoutIntervalForResource = timeoutIntervalForResource
        // iOS 14 might prompt user to allow connectivity to local network so we need to wait
        config.waitsForConnectivity = true
        return config
    }
    
    fileprivate func addApiKey(_ request: inout URLRequest) {
        if !apiKey.isEmpty {
            request.addValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        }
    }
    
    func buildURL(_ service: String) -> URL? {
        var serviceToAnalyze = service
        let urlFragment: String
        // No need to encode serverURL
        if service.starts(with: serverURL) {
            serviceToAnalyze = String(service.dropFirst(serverURL.count))
        }
        // Split into path and query params
        let parts = serviceToAnalyze.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: true).map(String.init)
        // Escape path and query params
        let path = parts[0].addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? parts[0]
        if parts.count > 1 {
            // We have query params
            let queryString = parts[1].addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? parts[1]
            urlFragment = "\(path)?\(queryString)"
        } else {
            urlFragment = path
        }
        return URL(string: serverURL + urlFragment)
    }

    // MARK: URLSessionDelegate

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

private class WrappedDownloadTaskDelegate: NSObject, URLSessionDownloadDelegate {
    
    private let progress: (Int64, Int64) -> Void
    private let completion: (Data?, Error?) -> Void
    private let httpClient: HTTPClient
    
    init(httpClient: HTTPClient, progress: @escaping (Int64, Int64) -> Void, completion: @escaping (Data?, Error?) -> Void) {
        self.progress = progress
        self.completion = completion
        self.httpClient = httpClient
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            let reader = try FileHandle(forReadingFrom: location)
            completion(reader.readDataToEndOfFile(), nil)
        } catch {
            completion(nil, error)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        completion(nil, error)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        progress(totalBytesWritten, totalBytesExpectedToWrite)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        httpClient.urlSession(session, task: task, didReceive: challenge, completionHandler: completionHandler)
    }
}
