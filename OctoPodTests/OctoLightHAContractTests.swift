import XCTest
@testable import OctoPod

final class OctoLightHAContractTests: XCTestCase {
    private var transport: ScriptedOctoLightTransport!
    private var service: OctoLightHAService!

    override func setUp() {
        super.setUp()
        transport = ScriptedOctoLightTransport()
        service = OctoLightHAService(transport: transport)
    }

    override func tearDown() {
        service = nil
        transport = nil
        super.tearDown()
    }

    func testUnknownAndModernControlsUsePostWhileReadsStayGet() {
        transport.script = [
            (modernState(false), nil, 200),
            (modernState(true), nil, 200),
            (modernState(false), nil, 200),
            (modernState(true), nil, 200),
            (modernState(true), nil, 200)
        ]

        XCTAssertEqual(perform(service.toggle), .updated(false))
        XCTAssertEqual(perform { self.service.turn(on: true, $0) }, .updated(true))
        XCTAssertEqual(perform { self.service.turn(on: false, $0) }, .updated(false))
        XCTAssertEqual(perform(service.readState), .updated(true))
        XCTAssertEqual(transport.calls, [
            RecordedOctoLightCall(operation: .toggle, api: .commands),
            RecordedOctoLightCall(operation: .turnOn, api: .commands),
            RecordedOctoLightCall(operation: .turnOff, api: .commands),
            RecordedOctoLightCall(operation: .readState, api: .commands)
        ])

        XCTAssertEqual(perform(service.toggle), .updated(true))
        XCTAssertEqual(transport.calls.last, RecordedOctoLightCall(operation: .toggle, api: .commands))
    }

    func testLegacyControlsUseGetAndNeverABareRead() {
        learnLegacy()
        transport.script = [
            (["state": false] as NSDictionary, nil, 200),
            (["state": true] as NSDictionary, nil, 200),
            (["state": false] as NSDictionary, nil, 200),
            (["state": true] as NSDictionary, nil, 200)
        ]

        XCTAssertEqual(perform(service.toggle), .updated(false))
        XCTAssertEqual(perform { self.service.turn(on: true, $0) }, .updated(true))
        XCTAssertEqual(perform { self.service.turn(on: false, $0) }, .updated(false))
        XCTAssertEqual(perform(service.readState), .updated(true))
        XCTAssertEqual(transport.calls, [
            RecordedOctoLightCall(operation: .readState, api: .commands),
            RecordedOctoLightCall(operation: .toggle, api: .legacy),
            RecordedOctoLightCall(operation: .turnOn, api: .legacy),
            RecordedOctoLightCall(operation: .turnOff, api: .legacy),
            RecordedOctoLightCall(operation: .readState, api: .legacy)
        ])
    }

    func testReadStateLearnsContractWithoutTreatingNullAsOff() {
        transport.script = [(["state": true] as NSDictionary, nil, 200)]
        XCTAssertEqual(perform(service.readState), .updated(true))

        transport.connectionChangeCounter += 1
        transport.script = [(modernState(nil), nil, 200), (modernState(false), nil, 200)]
        XCTAssertEqual(perform(service.readState), .stateUnknown)
        XCTAssertEqual(perform(service.toggle), .updated(false))
        XCTAssertEqual(transport.calls.suffix(2), [
            RecordedOctoLightCall(operation: .readState, api: .commands),
            RecordedOctoLightCall(operation: .toggle, api: .commands)
        ])

        transport.script = [(["state": false] as NSDictionary, nil, 200), (["state": true] as NSDictionary, nil, 200)]
        XCTAssertEqual(perform(service.readState), .updated(false))
        XCTAssertEqual(perform(service.toggle), .updated(true))
        XCTAssertEqual(transport.calls.suffix(2), [
            RecordedOctoLightCall(operation: .readState, api: .commands),
            RecordedOctoLightCall(operation: .toggle, api: .legacy)
        ])
    }

    func testPost405FallsBackOnceAndALaterReadCanCorrectTheGuess() {
        transport.script = [
            (nil, nil, 405),
            (["state": true] as NSDictionary, nil, 200),
            (["state": false] as NSDictionary, nil, 200),
            (modernState(false), nil, 200),
            (modernState(true), nil, 200)
        ]

        XCTAssertEqual(perform { self.service.turn(on: true, $0) }, .updated(true))
        XCTAssertEqual(transport.calls, [
            RecordedOctoLightCall(operation: .turnOn, api: .commands),
            RecordedOctoLightCall(operation: .turnOn, api: .legacy)
        ])

        XCTAssertEqual(perform { self.service.turn(on: true, $0) }, .updated(false))
        XCTAssertEqual(transport.calls.last, RecordedOctoLightCall(operation: .turnOn, api: .legacy))

        XCTAssertEqual(perform(service.readState), .updated(false))
        XCTAssertEqual(perform { self.service.turn(on: true, $0) }, .updated(true))
        XCTAssertEqual(transport.calls.last, RecordedOctoLightCall(operation: .turnOn, api: .commands))
    }

    func testMutatingGet405SwitchesToPostAndASecond405ForgetsTheGuess() {
        learnLegacy()
        transport.script = [
            (["error": "Use POST commands for light control."] as NSDictionary, nil, 405),
            (nil, nil, 405),
            (modernState(true), nil, 200)
        ]

        let failed = perform(service.toggle)
        XCTAssertEqual(failed, .failed(message: OctoLightHAFailure.rejected, statusCode: 405))
        XCTAssertEqual(transport.calls.suffix(2), [
            RecordedOctoLightCall(operation: .toggle, api: .legacy),
            RecordedOctoLightCall(operation: .toggle, api: .commands)
        ])

        XCTAssertEqual(perform(service.toggle), .updated(true))
        XCTAssertEqual(transport.calls.last, RecordedOctoLightCall(operation: .toggle, api: .commands))
    }

    func testExplicitNullStateIsSuccessWithoutAnotherCommand() {
        transport.script = [(modernState(nil), nil, 200)]
        XCTAssertEqual(perform { self.service.turn(on: true, $0) }, .stateUnknown)
        XCTAssertEqual(transport.calls, [RecordedOctoLightCall(operation: .turnOn, api: .commands)])
    }

    func testExplicitNullWithoutModernKeysIsNotLegacy() {
        transport.script = [
            (["state": NSNull()] as NSDictionary, nil, 200),
            (modernState(true), nil, 200)
        ]
        XCTAssertEqual(perform(service.readState), .stateUnknown)
        XCTAssertEqual(perform(service.toggle), .updated(true))
        XCTAssertEqual(transport.calls.last, RecordedOctoLightCall(operation: .toggle, api: .commands))
    }

    func testHttp200WithoutALightDocumentIsAFailureAndDoesNotRetry() {
        learnModern()
        transport.script = [
            (nil, nil, 200),
            (["ok": true] as NSDictionary, nil, 200),
            (["state": "on"] as NSDictionary, nil, 200),
            (["error": "Login required"] as NSDictionary, nil, 200),
            (modernState(true), nil, 200)
        ]

        XCTAssertEqual(perform { self.service.turn(on: true, $0) }, .failed(message: OctoLightHAFailure.unconfirmedResponse, statusCode: 200))
        XCTAssertEqual(perform(service.toggle), .failed(message: OctoLightHAFailure.unconfirmedResponse, statusCode: 200))
        let wrongType = perform(service.toggle)
        if case .failed(let message, let statusCode) = wrongType {
            XCTAssertFalse(message.isEmpty)
            XCTAssertEqual(statusCode, 200)
        } else {
            XCTFail("Expected a failed result for a string state")
        }
        XCTAssertEqual(perform { self.service.turn(on: false, $0) }, .failed(message: "Login required", statusCode: 200))
        XCTAssertEqual(transport.calls, [
            RecordedOctoLightCall(operation: .readState, api: .commands),
            RecordedOctoLightCall(operation: .turnOn, api: .commands),
            RecordedOctoLightCall(operation: .toggle, api: .commands),
            RecordedOctoLightCall(operation: .toggle, api: .commands),
            RecordedOctoLightCall(operation: .turnOff, api: .commands)
        ])

        XCTAssertEqual(perform { self.service.turn(on: true, $0) }, .updated(true))
        XCTAssertEqual(transport.calls.last, RecordedOctoLightCall(operation: .turnOn, api: .commands))
    }

    func testPluginRefusalsDoNotFallBack() {
        transport.script = [(["error": " The Home Assistant entity is unavailable. "] as NSDictionary, nil, 400)]
        XCTAssertEqual(
            perform { self.service.turn(on: false, $0) },
            .failed(message: "The Home Assistant entity is unavailable.", statusCode: 400)
        )
        XCTAssertEqual(transport.calls, [RecordedOctoLightCall(operation: .turnOff, api: .commands)])

        transport.connectionChangeCounter += 1
        transport.script = [(["error": ""] as NSDictionary, nil, 403)]
        XCTAssertEqual(perform(service.toggle), .failed(message: OctoLightHAFailure.rejected, statusCode: 403))
        XCTAssertEqual(transport.calls.last, RecordedOctoLightCall(operation: .toggle, api: .commands))

        transport.connectionChangeCounter += 1
        transport.script = [(nil, nil, 401), (modernState(false), nil, 200)]
        XCTAssertEqual(perform(service.toggle), .failed(message: OctoLightHAFailure.rejected, statusCode: 401))
        XCTAssertEqual(perform(service.toggle), .updated(false))
        XCTAssertEqual(transport.calls.suffix(2), [
            RecordedOctoLightCall(operation: .toggle, api: .commands),
            RecordedOctoLightCall(operation: .toggle, api: .commands)
        ])
    }

    func testTransportFailureDoesNotFallBackEvenWhenStatusLooksLike405() {
        learnModern()
        transport.script = [(nil, URLError(.timedOut), 405), (modernState(true), nil, 200)]

        let timedOut = perform(service.toggle)
        XCTAssertEqual(timedOut, .failed(message: URLError(.timedOut).localizedDescription, statusCode: 405))
        XCTAssertEqual(perform(service.toggle), .updated(true))
        XCTAssertEqual(transport.calls.suffix(2), [
            RecordedOctoLightCall(operation: .toggle, api: .commands),
            RecordedOctoLightCall(operation: .toggle, api: .commands)
        ])
    }

    func testReadState405DoesNotIssueAnotherRequest() {
        transport.script = [(nil, nil, 405), (modernState(true), nil, 200)]
        let failed = perform(service.readState)
        if case .failed = failed {
        } else {
            XCTFail("Expected the state read to fail")
        }
        XCTAssertEqual(transport.calls, [RecordedOctoLightCall(operation: .readState, api: .commands)])

        XCTAssertEqual(perform(service.toggle), .updated(true))
        XCTAssertEqual(transport.calls.last, RecordedOctoLightCall(operation: .toggle, api: .commands))
    }

    func testBothVerbs405StopAndTheNextTapStartsWithPost() {
        transport.script = [
            (nil, nil, 405),
            (nil, nil, 405),
            (modernState(true), nil, 200)
        ]
        XCTAssertEqual(perform(service.toggle), .failed(message: OctoLightHAFailure.rejected, statusCode: 405))
        XCTAssertEqual(transport.calls, [
            RecordedOctoLightCall(operation: .toggle, api: .commands),
            RecordedOctoLightCall(operation: .toggle, api: .legacy)
        ])

        XCTAssertEqual(perform(service.toggle), .updated(true))
        XCTAssertEqual(transport.calls.last, RecordedOctoLightCall(operation: .toggle, api: .commands))
    }

    func testConnectionChangeForgetsTheLearnedContract() {
        learnLegacy()
        transport.connectionChangeCounter += 1
        transport.script = [
            (nil, nil, 405),
            (["state": true] as NSDictionary, nil, 200)
        ]
        XCTAssertEqual(perform(service.toggle), .updated(true))
        XCTAssertEqual(transport.calls.suffix(2), [
            RecordedOctoLightCall(operation: .toggle, api: .commands),
            RecordedOctoLightCall(operation: .toggle, api: .legacy)
        ])
    }

    func testReplyFromAnOlderConnectionIsIgnored() {
        transport.hold = true
        transport.script = [(["state": true] as NSDictionary, nil, 200)]
        var received: OctoLightHAResult?
        service.toggle { received = $0 }
        XCTAssertEqual(transport.calls, [RecordedOctoLightCall(operation: .toggle, api: .commands)])

        transport.connectionChangeCounter += 1
        transport.releaseHeld()
        XCTAssertNil(received)

        transport.script = [
            (nil, nil, 405),
            (["state": true] as NSDictionary, nil, 200)
        ]
        XCTAssertEqual(perform(service.toggle), .updated(true))
        XCTAssertEqual(transport.calls.suffix(2), [
            RecordedOctoLightCall(operation: .toggle, api: .commands),
            RecordedOctoLightCall(operation: .toggle, api: .legacy)
        ])
    }

    /// JSON numbers 0 and 1 bridge to Swift Bool. These fixtures go through JSONSerialization so that bridge is present.
    func testNumericStateIsRejectedWithoutRetryOrALegacyGuess() throws {
        transport.script = [
            (try octoLightJSON("{\"state\":1}"), nil, 200),
            (try octoLightJSON("{\"state\":true,\"isLightOn\":true,\"entities\":[]}"), nil, 200)
        ]
        XCTAssertEqual(perform(service.toggle), .failed(message: OctoLightHAFailure.unconfirmedResponse, statusCode: 200))
        XCTAssertEqual(transport.calls, [RecordedOctoLightCall(operation: .toggle, api: .commands)])

        XCTAssertEqual(perform(service.toggle), .updated(true))
        XCTAssertEqual(transport.calls.last, RecordedOctoLightCall(operation: .toggle, api: .commands))
    }

    func testNumericIsLightOnIsRejectedAndJSONNullStaysUnknown() throws {
        transport.script = [
            (try octoLightJSON("{\"isLightOn\":0}"), nil, 200),
            (try octoLightJSON("{\"isLightOn\":null}"), nil, 200)
        ]
        XCTAssertEqual(perform(service.toggle), .failed(message: OctoLightHAFailure.unconfirmedResponse, statusCode: 200))
        XCTAssertEqual(transport.calls, [RecordedOctoLightCall(operation: .toggle, api: .commands)])

        XCTAssertEqual(perform(service.readState), .stateUnknown)
        XCTAssertEqual(transport.calls, [
            RecordedOctoLightCall(operation: .toggle, api: .commands),
            RecordedOctoLightCall(operation: .readState, api: .commands)
        ])
    }

    func testJSONNullStateIsUnknownAndDoesNotChangeTheContract() throws {
        transport.script = [
            (try octoLightJSON("{\"state\":null}"), nil, 200),
            (try octoLightJSON("{\"isLightOn\":true}"), nil, 200)
        ]
        XCTAssertEqual(perform(service.readState), .stateUnknown)
        XCTAssertEqual(perform(service.toggle), .updated(true))
        XCTAssertEqual(transport.calls, [
            RecordedOctoLightCall(operation: .readState, api: .commands),
            RecordedOctoLightCall(operation: .toggle, api: .commands)
        ])
    }

    private func learnLegacy() {
        transport.script = [(["state": false] as NSDictionary, nil, 200)]
        XCTAssertEqual(perform(service.readState), .updated(false))
    }

    private func learnModern() {
        transport.script = [(modernState(true), nil, 200)]
        XCTAssertEqual(perform(service.readState), .updated(true))
    }

    @discardableResult
    private func perform(_ call: (@escaping (OctoLightHAResult) -> Void) -> Void) -> OctoLightHAResult {
        var received: OctoLightHAResult?
        call { received = $0 }
        guard let received = received else {
            XCTFail("Expected an OctoLight result")
            return .failed(message: "", statusCode: 0)
        }
        return received
    }

    private func modernState(_ on: Bool?) -> NSDictionary {
        let json = NSMutableDictionary()
        if let on = on {
            json["state"] = on
            json["isLightOn"] = on
        } else {
            json["state"] = NSNull()
            json["isLightOn"] = NSNull()
        }
        json["entities"] = []
        return json
    }
}

/// Switches the live server after a connection snapshot is copied and before that snapshot is returned.
/// A dispatch that looks the server up again records B. A dispatch that uses the snapshot records A.
private final class SwitchingOctoLightTransport: OctoLightHATransport {
    private let lock = NSLock()
    private var connectionChangeCounter: UInt = 0
    private var server = "A"
    private var captures = 0
    private var recorded: [String] = []
    private var completed: OctoLightHAResult?
    private let snapshotReached = DispatchSemaphore(value: 0)
    private let resumeSnapshot = DispatchSemaphore(value: 0)
    /// 1 is the initial request. 3 is the 405 fallback: initial snapshot, response validation, then dispatch.
    var pauseOnCapture = 0

    func captureOctoLightConnection() -> OctoLightHAConnection? {
        lock.lock()
        captures += 1
        let index = captures
        let boundChangeCounter = connectionChangeCounter
        let boundServer = server
        lock.unlock()
        if index == pauseOnCapture {
            snapshotReached.signal()
            _ = resumeSnapshot.wait(timeout: .now() + 2)
        }
        return OctoLightHAConnection(
            connectionChangeCounter: boundChangeCounter,
            readState: { _, callback in
                self.record("GET \(boundServer) getState", response: .light(.boolean(true), api: .legacy), callback: callback)
            },
            toggle: { api, callback in
                switch api {
                case .commands:
                    self.record("POST \(boundServer) toggle", response: .methodRejected(statusCode: 405, pluginMessage: nil), callback: callback)
                case .legacy:
                    self.record("GET \(boundServer) toggle", response: .light(.boolean(true), api: .legacy), callback: callback)
                }
            },
            turn: { on, api, callback in
                let name = on ? "turnOn" : "turnOff"
                switch api {
                case .commands:
                    self.record("POST \(boundServer) \(name)", response: .methodRejected(statusCode: 405, pluginMessage: nil), callback: callback)
                case .legacy:
                    self.record("GET \(boundServer) \(name)", response: .light(.boolean(true), api: .legacy), callback: callback)
                }
            })
    }

    func switchToB() {
        lock.lock()
        connectionChangeCounter += 1
        server = "B"
        lock.unlock()
    }

    func waitForSnapshot() -> DispatchTimeoutResult {
        return snapshotReached.wait(timeout: .now() + 2)
    }

    func resume() {
        resumeSnapshot.signal()
    }

    var calls: [String] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    var completion: OctoLightHAResult? {
        lock.lock()
        defer { lock.unlock() }
        return completed
    }

    func store(_ result: OctoLightHAResult) {
        lock.lock()
        completed = result
        lock.unlock()
    }

    private func record(_ call: String, response: OctoLightHAResponse, callback: @escaping (OctoLightHAResponse) -> Void) {
        lock.lock()
        recorded.append(call)
        lock.unlock()
        callback(response)
    }
}

final class OctoLightHAConnectionRaceTests: XCTestCase {
    func testInitialRequestKeepsTheCapturedConnectionWhenThePrinterSwitches() {
        let transport = SwitchingOctoLightTransport()
        transport.pauseOnCapture = 1
        let service = OctoLightHAService(transport: transport)
        let finished = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            service.toggle { transport.store($0) }
            finished.signal()
        }

        XCTAssertEqual(transport.waitForSnapshot(), .success)
        transport.switchToB()
        transport.resume()
        XCTAssertEqual(finished.wait(timeout: .now() + 2), .success)
        XCTAssertEqual(transport.calls, ["POST A toggle"])
        XCTAssertNil(transport.completion)
    }

    func testFallbackKeepsTheCapturedConnectionWhenThePrinterSwitchesBeforeDispatch() {
        let transport = SwitchingOctoLightTransport()
        transport.pauseOnCapture = 3
        let service = OctoLightHAService(transport: transport)
        let finished = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            service.toggle { transport.store($0) }
            finished.signal()
        }

        XCTAssertEqual(transport.waitForSnapshot(), .success)
        transport.switchToB()
        transport.resume()
        XCTAssertEqual(finished.wait(timeout: .now() + 2), .success)
        XCTAssertEqual(transport.calls, ["POST A toggle", "GET A toggle"])
        XCTAssertNil(transport.completion)
    }
}

final class OctoLightHAConnectionChangeTests: PrinterManagerTestCase {
    /// The counter is private. Identity is the snapshot taken with the HTTP client, not a test-only getter.
    func testReplacingOrClearingTheConnectionChangesTheSnapshot() throws {
        let client = OctoPrintClient(printerManager: printerManager, appConfiguration: AppConfiguration())
        XCTAssertNil(client.captureOctoLightConnection())

        let printerID = try insertPrinter(defaultPrinter: true, hostname: "http://127.0.0.1:9")
        let printer = try XCTUnwrap(persistentContainer.viewContext.object(with: printerID) as? Printer)
        printer.apiKey = "test-key"
        try persistentContainer.viewContext.save()

        client.connectToServer(printer: printer)
        let first = try XCTUnwrap(client.captureOctoLightConnection())
        let firstHTTP = try XCTUnwrap(client.octoPrintRESTClient.httpClient)

        client.disconnectFromServer()
        XCTAssertNil(client.captureOctoLightConnection())

        client.connectToServer(printer: printer)
        let second = try XCTUnwrap(client.captureOctoLightConnection())
        let secondHTTP = try XCTUnwrap(client.octoPrintRESTClient.httpClient)
        // Disconnect clears the connection and connect installs the next one.
        XCTAssertEqual(second.connectionChangeCounter, first.connectionChangeCounter + 2)
        XCTAssertFalse(firstHTTP === secondHTTP)

        var firstSawRequest = false
        var secondSawRequest = false
        firstHTTP.preRequest = { firstSawRequest = true }
        secondHTTP.preRequest = { secondSawRequest = true }
        first.toggleOctoLightHA(api: .commands) { _ in }
        XCTAssertTrue(firstSawRequest)
        XCTAssertFalse(secondSawRequest)

        client.disconnectFromServer()
    }
}

/// Parses plugin documents the same way HTTPClient does, then uses the production decoder.
final class OctoLightHAJSONDecodingTests: XCTestCase {
    func testStateAcceptsJSONBooleansAndNullAndRejectsNumbersAndStrings() throws {
        XCTAssertEqual(try decode("{\"state\":true}"), .light(.boolean(true), api: .legacy))
        XCTAssertEqual(try decode("{\"state\":false}"), .light(.boolean(false), api: .legacy))
        XCTAssertEqual(try decode("{\"state\":null}"), .light(.explicitNull, api: nil))
        XCTAssertEqual(try decode("{\"state\":1}"), .invalid(statusCode: 200, pluginMessage: nil))
        XCTAssertEqual(try decode("{\"state\":0}"), .invalid(statusCode: 200, pluginMessage: nil))
        XCTAssertEqual(try decode("{\"state\":\"on\"}"), .invalid(statusCode: 200, pluginMessage: nil))
    }

    func testIsLightOnUsesTheSameBooleanCheck() throws {
        XCTAssertEqual(try decode("{\"isLightOn\":true}"), .light(.boolean(true), api: .commands))
        XCTAssertEqual(try decode("{\"isLightOn\":false}"), .light(.boolean(false), api: .commands))
        XCTAssertEqual(try decode("{\"isLightOn\":null}"), .light(.explicitNull, api: .commands))
        XCTAssertEqual(try decode("{\"isLightOn\":1}"), .invalid(statusCode: 200, pluginMessage: nil))
        XCTAssertEqual(try decode("{\"isLightOn\":0}"), .invalid(statusCode: 200, pluginMessage: nil))
        XCTAssertEqual(try decode("{\"isLightOn\":\"off\"}"), .invalid(statusCode: 200, pluginMessage: nil))
    }

    private func decode(_ text: String) throws -> OctoLightHAResponse {
        return OctoPrintRESTClient.decodeOctoLightHA(result: try octoLightJSON(text), error: nil, statusCode: 200)
    }
}

private func octoLightJSON(_ text: String) throws -> NSObject {
    let data = Data(text.utf8)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: data, options: [.mutableLeaves, .mutableContainers]) as? NSObject)
}

private struct RecordedOctoLightCall: Equatable {
    enum Operation: Equatable {
        case readState
        case toggle
        case turnOn
        case turnOff
    }

    let operation: Operation
    let api: OctoLightHAAPI
}

private final class ScriptedOctoLightTransport: OctoLightHATransport {
    var connectionChangeCounter: UInt = 0
    var calls: [RecordedOctoLightCall] = []
    var script: [(NSObject?, Error?, Int)] = []
    var hold = false
    private var held: (() -> Void)?

    func captureOctoLightConnection() -> OctoLightHAConnection? {
        let changeCounter = connectionChangeCounter
        return OctoLightHAConnection(
            connectionChangeCounter: changeCounter,
            readState: { api, callback in self.record(.readState, api: api, callback: callback) },
            toggle: { api, callback in self.record(.toggle, api: api, callback: callback) },
            turn: { on, api, callback in self.record(on ? .turnOn : .turnOff, api: api, callback: callback) })
    }

    func releaseHeld() {
        let deliver = held
        held = nil
        hold = false
        deliver?()
    }

    private func record(_ operation: RecordedOctoLightCall.Operation, api: OctoLightHAAPI, callback: @escaping (OctoLightHAResponse) -> Void) {
        calls.append(RecordedOctoLightCall(operation: operation, api: api))
        reply(callback)
    }

    private func reply(_ callback: @escaping (OctoLightHAResponse) -> Void) {
        precondition(!script.isEmpty, "Missing scripted OctoLight response")
        let next = script.removeFirst()
        let deliver = {
            callback(OctoPrintRESTClient.decodeOctoLightHA(result: next.0, error: next.1, statusCode: next.2))
        }
        if hold {
            held = deliver
        } else {
            deliver()
        }
    }
}
