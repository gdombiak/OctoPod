import XCTest
@testable import OctoPod

final class PrinterManagerDiagnosticTests: PrinterManagerTestCase {
    func testPrinterSaveDiagnosticDoesNotExposeErrorUserInfoValues() throws {
        let printerID = try insertPrinter(defaultPrinter: false, hostname: "before")
        let context = persistentContainer.viewContext
        context.name = "test.diagnostics"
        let secret = "api-key-should-not-appear"
        let error = NSError(domain: "TestSaveDomain", code: 42, userInfo: [
            "apiKey": secret,
            "hostname": "private-printer.local",
            NSLocalizedDescriptionKey: "The save failed"
        ])

        let diagnostic = PrinterManager.printerSaveDiagnostic(error, context: context, objectID: printerID)

        XCTAssertTrue(diagnostic.contains("writer=test.diagnostics"))
        XCTAssertTrue(diagnostic.contains("domain=TestSaveDomain"))
        XCTAssertTrue(diagnostic.contains("code=42"))
        XCTAssertTrue(diagnostic.contains("description=The save failed"))
        XCTAssertFalse(diagnostic.contains(secret))
        XCTAssertFalse(diagnostic.contains("private-printer.local"))
    }

    func testPrinterConflictKeysOnlyIncludePropertiesChangedByBothWriters() {
        let currentSecret = "current-api-key"
        let storeSecret = "store-api-key"
        let keys = PrinterManager.conflictingPrinterPropertyKeys(
            objectSnapshot: ["apiKey": currentSecret, "hostname": "current.local", "defaultPrinter": true],
            cachedSnapshot: ["apiKey": "old-api-key", "hostname": "old.local", "defaultPrinter": false],
            persistedSnapshot: ["apiKey": storeSecret, "hostname": "old.local", "defaultPrinter": false]
        )

        XCTAssertEqual(keys, ["apiKey"])
        XCTAssertFalse(keys.contains(currentSecret))
        XCTAssertFalse(keys.contains(storeSecret))
    }
}
