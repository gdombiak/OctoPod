import WatchConnectivity
import XCTest
@testable import OctoPod

final class WatchJobCommandTests: PrinterManagerTestCase {
    func testAmbiguousNameRejectsJobCommandWithoutContactingEitherPrinter() throws {
        let first = try makeServer()
        let second = try makeServer()
        defer {
            first.stop()
            second.stop()
        }
        try addPrinter(named: "Workshop", on: first, isDefault: true)
        try addPrinter(named: "Workshop", on: second)
        let manager = makeWatchSessionManager()

        let reply = send("pause_job", printer: "Workshop", to: manager)

        XCTAssertNotNil(reply["error"])
        XCTAssertTrue(first.requests.isEmpty)
        XCTAssertTrue(second.requests.isEmpty)
    }

    func testUniqueNameRunsEachJobCommandWithoutASharedConnection() throws {
        let selected = try makeServer()
        let requested = try makeServer()
        defer {
            selected.stop()
            requested.stop()
        }
        try addPrinter(named: "Selected on iPhone", on: selected, isDefault: true)
        try addPrinter(named: "Selected on Watch", on: requested)
        let manager = makeWatchSessionManager()
        XCTAssertFalse(manager.octoprintClient.octoPrintRESTClient.isConfigured())

        for command in ["pause_job", "resume_job", "cancel_job"] {
            let reply = send(command, printer: "Selected on Watch", to: manager)
            XCTAssertEqual(reply as? [String: String], ["": ""])
        }

        XCTAssertTrue(selected.requests.isEmpty)
        let requests = requested.requests
        XCTAssertEqual(requests.map(\.method), ["POST", "POST", "POST"])
        XCTAssertEqual(requests.map(\.target), ["/api/job", "/api/job", "/api/job"])
        let bodies = try requests.map { request in
            try XCTUnwrap(JSONSerialization.jsonObject(with: Data(request.body.utf8)) as? [String: String])
        }
        XCTAssertEqual(bodies, [
            ["command": "pause", "action": "pause"],
            ["command": "pause", "action": "resume"],
            ["command": "cancel"]
        ])
    }

    private func makeServer() throws -> LoopbackHTTPServer {
        let server = try LoopbackHTTPServer()
        server.reply = { _, _, _ in LoopbackHTTPResponse(status: 204, body: "") }
        return server
    }

    private func addPrinter(named name: String, on server: LoopbackHTTPServer, isDefault: Bool = false) throws {
        let id = try insertPrinter(defaultPrinter: isDefault, hostname: "http://127.0.0.1:\(server.port)")
        let context = persistentContainer.viewContext
        let printer = try XCTUnwrap(context.existingObject(with: id) as? Printer)
        printer.name = name
        printer.apiKey = "fixture"
        try context.save()
    }

    private func makeWatchSessionManager() -> WatchSessionManager {
        let client = OctoPrintClient(printerManager: printerManager, appConfiguration: AppConfiguration())
        return WatchSessionManager(
            printerManager: printerManager,
            cloudKitPrinterManager: CloudKitPrinterManager(printerManager: printerManager),
            octoprintClient: client
        )
    }

    private func send(_ command: String, printer: String, to manager: WatchSessionManager) -> [String: Any] {
        let received = expectation(description: "\(command) reply")
        var result: [String: Any] = [:]
        manager.session(WCSession.default, didReceiveMessage: [command: printer]) { reply in
            result = reply
            received.fulfill()
        }
        wait(for: [received], timeout: 5)
        return result
    }
}
