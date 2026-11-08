import XCTest
@testable import OctoPod

/// Drives OctoPrintRESTClient through HTTPClient and URLSession against a localhost socket.
/// Scripted senders cannot reproduce URLSession's POST-to-GET redirect rewrite.
final class OctoLightHAHTTPTests: XCTestCase {
    private var server: LoopbackHTTPServer?

    override func tearDown() {
        server?.stop()
        server = nil
        super.tearDown()
    }

    func testMethodChangingRedirectDoesNotReportTheFollowingStateReadAsSuccess() throws {
        let server = try startServer { _, _, _ in nil }
        server.reply = { method, target, _ in
            if method == "POST" && target == "/api/plugin/octolightHA" {
                return LoopbackHTTPResponse(status: 302, headers: ["Location": "http://127.0.0.1:\(server.port)/read"], body: "")
            }
            return LoopbackHTTPResponse(status: 200, body: "{\"state\":false,\"isLightOn\":false,\"entities\":[]}")
        }

        let result = try performTurnOn(port: server.port)
        XCTAssertEqual(result, .failed(message: OctoLightHAFailure.unconfirmedRedirect, statusCode: 302))
        XCTAssertEqual(server.requests.map { $0.method }, ["POST"])
    }

    func testSameMethodRedirectStillDeliversThePostBody() throws {
        let server = try startServer { _, _, _ in nil }
        server.reply = { method, target, _ in
            if method == "POST" && target == "/api/plugin/octolightHA" {
                return LoopbackHTTPResponse(status: 307, headers: ["Location": "http://127.0.0.1:\(server.port)/final"], body: "")
            }
            return LoopbackHTTPResponse(status: 200, body: "{\"state\":true}")
        }

        let result = try performTurnOn(port: server.port)
        XCTAssertEqual(result, .updated(true))
        XCTAssertEqual(server.requests.map { "\($0.method) \($0.target)" }, ["POST /api/plugin/octolightHA", "POST /final"])
        XCTAssertTrue(server.requests[1].body.contains("\"command\":\"turnOn\""))
    }

    func testOrdinaryGetStillFollowsARedirect() throws {
        let server = try startServer { _, _, _ in nil }
        server.reply = { _, target, _ in
            if target == "/start" {
                return LoopbackHTTPResponse(status: 302, headers: ["Location": "http://127.0.0.1:\(server.port)/landed"], body: "")
            }
            return LoopbackHTTPResponse(status: 200, body: "{\"ok\":true}")
        }
        let client = try connectedClient(port: server.port)
        let done = expectation(description: "GET redirect")
        var body: NSDictionary?
        var status = 0
        client.httpClient?.get("/start") { result, error, response in
            body = result as? NSDictionary
            status = response.statusCode
            XCTAssertNil(error)
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        XCTAssertEqual(status, 200)
        XCTAssertEqual(body?["ok"] as? Bool, true)
        XCTAssertEqual(server.requests.map { "\($0.method) \($0.target)" }, ["GET /start", "GET /landed"])
    }

    func testHtmlAndMalformedSuccessBodiesDoNotCountAsUnknownState() throws {
        let server = try startServer { _, _, _ in nil }
        server.reply = { _, _, _ in
            LoopbackHTTPResponse(status: 200, headers: ["Content-Type": "text/html"], body: "<html><body>Login</body></html>")
        }
        let html = try performTurnOn(port: server.port)
        XCTAssertEqual(html, .failed(message: OctoLightHAFailure.unconfirmedResponse, statusCode: 200))
        XCTAssertEqual(server.requests.count, 1)

        server.requests = []
        server.reply = { _, _, _ in
            LoopbackHTTPResponse(status: 200, body: "{\"state\":")
        }
        let malformed = try performTurnOn(port: server.port)
        XCTAssertEqual(malformed, .failed(message: OctoLightHAFailure.unconfirmedResponse, statusCode: 200))
        XCTAssertEqual(server.requests.count, 1)
    }

    func testExplicitNullStateOverHttpRemainsUnknownSuccess() throws {
        let server = try startServer { _, _, _ in
            LoopbackHTTPResponse(status: 200, body: "{\"state\":null,\"isLightOn\":null,\"entities\":[]}")
        }
        let result = try performTurnOn(port: server.port)
        XCTAssertEqual(result, .stateUnknown)
        XCTAssertEqual(server.requests.count, 1)
    }

    func testHtml405StillFallsBackToTheLegacyGet() throws {
        let server = try startServer { method, _, _ in
            if method == "POST" {
                return LoopbackHTTPResponse(status: 405, headers: ["Content-Type": "text/html"], body: "<html>Method Not Allowed</html>")
            }
            return LoopbackHTTPResponse(status: 200, body: "{\"state\":true}")
        }
        let result = try performTurnOn(port: server.port)
        XCTAssertEqual(result, .updated(true))
        XCTAssertEqual(server.requests.map { "\($0.method) \($0.target)" }, [
            "POST /api/plugin/octolightHA",
            "GET /api/plugin/octolightHA?action=turnOn"
        ])
    }

    func testPluginRefusalAndDroppedConnectionDoNotRetry() throws {
        let server = try startServer { _, _, _ in
            LoopbackHTTPResponse(status: 400, body: "{\"error\":\"Entity not found in Home Assistant.\"}")
        }
        let refused = try performTurnOn(port: server.port)
        XCTAssertEqual(refused, .failed(message: "Entity not found in Home Assistant.", statusCode: 400))
        XCTAssertEqual(server.requests.map { $0.method }, ["POST"])

        server.requests = []
        server.reply = { _, _, _ in nil }
        let dropped = try performTurnOn(port: server.port)
        guard case .failed(let message, _) = dropped else {
            XCTFail("Expected a transport failure")
            return
        }
        XCTAssertFalse(message.isEmpty)
        XCTAssertNotEqual(message, OctoLightHAFailure.unconfirmedRedirect)
        XCTAssertNotEqual(message, OctoLightHAFailure.unconfirmedResponse)
        XCTAssertEqual(server.requests.map { $0.method }, ["POST"])
    }

    func testStateReadUsesTheGetStateAction() throws {
        let server = try startServer { _, _, _ in
            LoopbackHTTPResponse(status: 200, body: "{\"state\":true}")
        }
        let service = try lightService(port: server.port)
        let done = expectation(description: "state")
        var result: OctoLightHAResult?
        service.readState {
            result = $0
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        XCTAssertEqual(result, .updated(true))
        XCTAssertEqual(server.requests.map { "\($0.method) \($0.target)" }, ["GET /api/plugin/octolightHA?action=getState"])
    }

    private func startServer(reply: @escaping (String, String, String) -> LoopbackHTTPResponse?) throws -> LoopbackHTTPServer {
        let server = try LoopbackHTTPServer()
        server.reply = reply
        self.server = server
        return server
    }

    private func connectedClient(port: UInt16) throws -> OctoPrintRESTClient {
        let client = OctoPrintRESTClient()
        client.connectToServer(serverURL: "http://127.0.0.1:\(port)", apiKey: "test-key", username: nil, password: nil, headers: nil, preemptive: false)
        client.timeoutIntervalForRequest = 3
        client.timeoutIntervalForResource = 5
        return client
    }

    private func lightService(port: UInt16) throws -> OctoLightHAService {
        let client = try connectedClient(port: port)
        return OctoLightHAService(transport: RESTBackedOctoLightTransport(client: client))
    }

    private func performTurnOn(port: UInt16) throws -> OctoLightHAResult {
        let service = try lightService(port: port)
        let done = expectation(description: "turn on")
        var received: OctoLightHAResult?
        service.turn(on: true) { result in
            XCTAssertNil(received)
            received = result
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        return try XCTUnwrap(received)
    }
}

private final class RESTBackedOctoLightTransport: OctoLightHATransport {
    let client: OctoPrintRESTClient
    var connectionChangeCounter: UInt = 0

    init(client: OctoPrintRESTClient) {
        self.client = client
    }

    func captureOctoLightConnection() -> OctoLightHAConnection? {
        guard let httpClient = client.httpClient else { return nil }
        return OctoLightHAConnection(
            connectionChangeCounter: connectionChangeCounter,
            readState: { api, callback in
                OctoPrintRESTClient.getOctoLightHAState(api: api, client: httpClient, callback: callback)
            },
            toggle: { api, callback in
                OctoPrintRESTClient.toggleOctoLightHA(api: api, client: httpClient, callback: callback)
            },
            turn: { on, api, callback in
                OctoPrintRESTClient.turnOctoLightHA(on: on, api: api, client: httpClient, callback: callback)
            })
    }
}

private struct LoopbackHTTPResponse {
    var status: Int
    var headers: [String: String] = [:]
    var body: String
}

private final class LoopbackHTTPServer {
    private let listenFD: Int32
    private let lock = NSLock()
    private var stopped = false
    private var recorded: [(method: String, target: String, body: String)] = []
    private var replyHandler: (String, String, String) -> LoopbackHTTPResponse? = { _, _, _ in nil }
    let port: UInt16
    var reply: (String, String, String) -> LoopbackHTTPResponse? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return replyHandler
        }
        set {
            lock.lock()
            replyHandler = newValue
            lock.unlock()
        }
    }

    var requests: [(method: String, target: String, body: String)] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return recorded
        }
        set {
            lock.lock()
            recorded = newValue
            lock.unlock()
        }
    }

    init() throws {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        if fd < 0 {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout.size(ofValue: yes)))
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout.size(ofValue: yes)))
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if bound != 0 || listen(fd, 16) != 0 {
            close(fd)
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        var resolved = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &resolved) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(fd, $0, &length)
            }
        }
        if named != 0 {
            close(fd)
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        listenFD = fd
        port = CFSwapInt16BigToHost(resolved.sin_port)
        Thread.detachNewThread { [weak self] in
            self?.acceptLoop()
        }
    }

    func stop() {
        lock.lock()
        stopped = true
        lock.unlock()
        close(listenFD)
    }

    private func acceptLoop() {
        while true {
            lock.lock()
            let shouldStop = stopped
            lock.unlock()
            if shouldStop { break }
            let client = accept(listenFD, nil, nil)
            if client < 0 { break }
            var yes: Int32 = 1
            setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout.size(ofValue: yes)))
            var timeout = timeval(tv_sec: 2, tv_usec: 0)
            setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
            if let request = readRequest(client) {
                record(request)
                lock.lock()
                let handler = replyHandler
                lock.unlock()
                if let response = handler(request.method, request.target, request.body) {
                    write(response, to: client)
                }
            }
            close(client)
        }
    }

    private func record(_ request: (method: String, target: String, body: String)) {
        lock.lock()
        recorded.append(request)
        lock.unlock()
    }

    private func readRequest(_ fd: Int32) -> (method: String, target: String, body: String)? {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while data.range(of: Data("\r\n\r\n".utf8)) == nil {
            let count = buffer.withUnsafeMutableBytes { raw in
                recv(fd, raw.baseAddress!, raw.count, 0)
            }
            if count <= 0 { return nil }
            data.append(contentsOf: buffer.prefix(count))
            if data.count > 1024 * 1024 { return nil }
        }
        guard let headerEnd = data.range(of: Data("\r\n\r\n".utf8)),
              let headerText = String(data: data.subdata(in: 0..<headerEnd.lowerBound), encoding: .utf8) else {
            return nil
        }
        let contentLength = Self.contentLength(headerText)
        let bodyStart = headerEnd.upperBound
        while data.count < bodyStart + contentLength {
            let count = buffer.withUnsafeMutableBytes { raw in
                recv(fd, raw.baseAddress!, raw.count, 0)
            }
            if count <= 0 { break }
            data.append(contentsOf: buffer.prefix(count))
        }
        let lines = headerText.components(separatedBy: "\r\n")
        let parts = lines.first?.split(separator: " ").map(String.init) ?? []
        guard parts.count >= 2 else { return nil }
        let bodyEnd = min(data.count, bodyStart + contentLength)
        let body = String(data: data.subdata(in: bodyStart..<bodyEnd), encoding: .utf8) ?? ""
        return (parts[0], parts[1], body)
    }

    private func write(_ response: LoopbackHTTPResponse, to fd: Int32) {
        var headers = response.headers
        headers["Content-Length"] = "\(response.body.utf8.count)"
        headers["Connection"] = "close"
        if headers["Content-Type"] == nil {
            headers["Content-Type"] = "application/json"
        }
        let reason: String
        switch response.status {
        case 200: reason = "OK"
        case 302: reason = "Found"
        case 307: reason = "Temporary Redirect"
        case 400: reason = "Bad Request"
        case 405: reason = "Method Not Allowed"
        default: reason = "Status"
        }
        var text = "HTTP/1.1 \(response.status) \(reason)\r\n"
        for (name, value) in headers {
            text += "\(name): \(value)\r\n"
        }
        text += "\r\n"
        text += response.body
        let payload = Data(text.utf8)
        payload.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            var sent = 0
            while sent < raw.count {
                let count = send(fd, base.advanced(by: sent), raw.count - sent, 0)
                if count <= 0 { break }
                sent += count
            }
        }
    }

    private static func contentLength(_ headers: String) -> Int {
        for line in headers.components(separatedBy: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
            if parts.count == 2 && parts[0].lowercased() == "content-length" {
                return Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 0
            }
        }
        return 0
    }
}
