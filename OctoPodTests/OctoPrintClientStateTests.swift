import XCTest
@testable import OctoPod

final class OctoPrintClientStateTests: PrinterManagerTestCase {
    func testConcurrentPrinterStateReplacement() {
        let appConfiguration = AppConfiguration()
        let client = OctoPrintClient(printerManager: printerManager, appConfiguration: appConfiguration)
        defer { appConfiguration.remove(appConfigurationDelegate: client) }
        client.delegates = []

        // Keep the update path focused on the cache, without temperature, log, or printer lookups.
        let printerURL = "http://["
        XCTAssertNil(URL(string: printerURL))

        let replaceState = {
            for _ in 0..<100_000 {
                client.currentStateUpdated(event: CurrentStateEvent(printerURL: printerURL))
                withExtendedLifetime(client.lastKnownState) {}
            }
        }

        let started = DispatchSemaphore(value: 0)
        let finished = expectation(description: "background state updates finished")
        DispatchQueue.global(qos: .userInitiated).async {
            started.signal()
            replaceState()
            finished.fulfill()
        }
        XCTAssertEqual(started.wait(timeout: .now() + 5), .success)
        replaceState()
        wait(for: [finished], timeout: 5)

        XCTAssertEqual(client.lastKnownState?.printerURL, printerURL)
    }
}
