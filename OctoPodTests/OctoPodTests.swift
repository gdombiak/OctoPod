import XCTest
import CoreData
@testable import OctoPod

class OctoPodTests: XCTestCase {

    private struct PrinterState {
        let defaultPrinter: Bool
        let hostname: String
        let recordName: String?
    }

    private enum TestSaveError: Error {
        case forced
    }

    private final class FailingSaveContext: NSManagedObjectContext, @unchecked Sendable {
        override func save() throws {
            throw TestSaveError.forced
        }
    }

    private var persistentContainer: NSPersistentContainer!
    private var printerManager: PrinterManager!

    override func setUpWithError() throws {
        let modelURL = Bundle(for: Printer.self).url(forResource: "OctoPod", withExtension: "momd")!
        let model = NSManagedObjectModel(contentsOf: modelURL)!
        persistentContainer = NSPersistentContainer(name: "OctoPod", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        persistentContainer.persistentStoreDescriptions = [description]

        let loaded = expectation(description: "in-memory store loaded")
        persistentContainer.loadPersistentStores { _, error in
            XCTAssertNil(error)
            loaded.fulfill()
        }
        wait(for: [loaded], timeout: 2)

        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        persistentContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        printerManager = PrinterManager(managedObjectContext: persistentContainer.viewContext, persistentContainer: persistentContainer)
    }

    override func tearDownWithError() throws {
        persistentContainer = nil
        printerManager = nil
    }

    /// Test that URL validation works fine
    func testValidURLs() throws {
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://octopi.local"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "https://octopi.local"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://www.hola.com"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://www.hola.com:89"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://www.hola.com/"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://www.hola.com:89/"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://www.hola.com/chau"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://www.hola.com:89/chau"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://192.168.1.1"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://192.168.1.1:89"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://192.168.1.1/"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://192.168.1.1:89/"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://192.168.1.1/chau"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://192.168.1.1:89/chau"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://192.168.1.1/chau/"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://192.168.1.1:89/chau/"))

        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://2001:db8:3c4d:0015:0000:0000:1a2f:1a2b"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://2001:db8:3c4d:0015:0000:0000:1a2f:1a2b/"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://2001:db8:3c4d:0015:0000:0000:1a2f:1a2b:89"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://2001:db8:3c4d:0015:0000:0000:1a2f:1a2b:89/"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://2001:db8:3c4d:0015:0000:0000:1a2f:1a2b:89/chau"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://2001:db8:3c4d:0015:0000:0000:1a2f:1a2b:89/chau/"))

        XCTAssertFalse(PrinterUtils.isValidURL(inputURL: "qweqwe"))
        XCTAssertFalse(PrinterUtils.isValidURL(inputURL: "www.google.com"))
        XCTAssertFalse(PrinterUtils.isValidURL(inputURL: "http://http://www.google.com"))
        XCTAssertFalse(PrinterUtils.isValidURL(inputURL: "http://www.goo gle.com"))
    }
    
    func testHTTClientURLs() throws {
        let httpClient = HTTPClient(serverURL: "http://octopi.local", apiKey: "asd", username: nil, password: nil, headers: nil)
        
        XCTAssertNotNil(httpClient.buildURL("/plugin/asd"))
        XCTAssertNotNil(httpClient.buildURL("/plugin/prusaslicerthumbnails/thumbnail/E_PLA affe-c.png?20210812223724"))
        XCTAssertNotNil(httpClient.buildURL("/plugin/prusaslicerthumbnails/thumbnail/E_PLA hundepaar.png?20210812220714"))
        XCTAssertNotNil(httpClient.buildURL("/plugin/prusaslicerthumbnails/thumbnail/CE5_cube (1).gcode?20210812220714"))
        XCTAssertNotNil(httpClient.buildURL("/plugin/prusaslicerthumbnails/thumbnail/CE5_cube >(1).gcode?20210812220714"))
        XCTAssertNotNil(httpClient.buildURL("/plugin/prusaslicerthumbnails/thumbnail/CE5_cube #(1).gcode?20210812220714"))
        XCTAssertNotNil(httpClient.buildURL("/plugin/prusaslicerthumbnails/thumbnail/CE5_cube $(1).gcode?20210812220714"))
        XCTAssertNotNil(httpClient.buildURL("/plugin/prusaslicerthumbnails/thumbnail/CE5_cube ?(1).gcode?20210812220714"))
        
        var url = httpClient.buildURL("/plugin/prusaslicerthumbnails/thumbnail/CE5_cube >(1).gcode?20210812220714")
        XCTAssertEqual(url?.absoluteString, "http://octopi.local/plugin/prusaslicerthumbnails/thumbnail/CE5_cube%20%3E(1).gcode?20210812220714")
        XCTAssertEqual(url?.path, "/plugin/prusaslicerthumbnails/thumbnail/CE5_cube >(1).gcode")
        XCTAssertEqual(url?.query, "20210812220714")

        // Filenames with ? are trouble. It will generate some URL but will not work
        url = httpClient.buildURL("/plugin/prusaslicerthumbnails/thumbnail/CE5_cube ?(1).gcode?20210812220714")
        XCTAssertEqual(url?.absoluteString, "http://octopi.local/plugin/prusaslicerthumbnails/thumbnail/CE5_cube%20?(1).gcode?20210812220714")
        XCTAssertEqual(url?.path, "/plugin/prusaslicerthumbnails/thumbnail/CE5_cube ")
        XCTAssertEqual(url?.query, "(1).gcode?20210812220714")

        // Test that absolute path still works. Protocol is not encoded but path and query params do
        url = httpClient.buildURL("http://octopi.local/plugin/prusaslicerthumbnails/thumbnail/CE5_cube >(1).gcode?20210812220714")
        XCTAssertEqual(url?.absoluteString, "http://octopi.local/plugin/prusaslicerthumbnails/thumbnail/CE5_cube%20%3E(1).gcode?20210812220714")
        XCTAssertEqual(url?.path, "/plugin/prusaslicerthumbnails/thumbnail/CE5_cube >(1).gcode")
        XCTAssertEqual(url?.query, "20210812220714")
    }

    func testSiblingContextsPreserveDifferentPrinterProperties() throws {
        let printerID = try insertPrinter(defaultPrinter: false, hostname: "before")
        let defaultWriter = printerManager.newPrivateContext(writer: "test.default")
        let connectionWriter = printerManager.newPrivateContext(writer: "test.connection")

        defaultWriter.performAndWait {
            let printer = defaultWriter.object(with: printerID) as! Printer
            printer.defaultPrinter = true
        }
        connectionWriter.performAndWait {
            let printer = connectionWriter.object(with: printerID) as! Printer
            printer.hostname = "after"
        }
        defaultWriter.performAndWait {
            XCTAssertTrue(printerManager.updatePrinter(defaultWriter.object(with: printerID) as! Printer, context: defaultWriter))
        }
        connectionWriter.performAndWait {
            XCTAssertTrue(printerManager.updatePrinter(connectionWriter.object(with: printerID) as! Printer, context: connectionWriter))
        }

        let result = try fetchPrinterState(id: printerID)
        XCTAssertTrue(result.defaultPrinter)
        XCTAssertEqual(result.hostname, "after")
    }

    func testSiblingContextsUseLastSavingWriterForSamePrinterProperty() throws {
        let printerID = try insertPrinter(defaultPrinter: false, hostname: "before")
        let firstWriter = printerManager.newPrivateContext(writer: "test.first")
        let secondWriter = printerManager.newPrivateContext(writer: "test.second")

        firstWriter.performAndWait {
            let printer = firstWriter.object(with: printerID) as! Printer
            printer.hostname = "first"
        }
        secondWriter.performAndWait {
            let printer = secondWriter.object(with: printerID) as! Printer
            printer.hostname = "second"
        }
        firstWriter.performAndWait {
            XCTAssertTrue(printerManager.updatePrinter(firstWriter.object(with: printerID) as! Printer, context: firstWriter))
        }
        secondWriter.performAndWait {
            XCTAssertTrue(printerManager.updatePrinter(secondWriter.object(with: printerID) as! Printer, context: secondWriter))
        }

        XCTAssertEqual(try fetchPrinterState(id: printerID).hostname, "second")
    }

    func testFailedPrivateSaveDoesNotDiscardPendingViewContextEdit() throws {
        let printerID = try insertPrinter(defaultPrinter: false, hostname: "before")
        let viewPrinter = try persistentContainer.viewContext.existingObject(with: printerID) as! Printer
        viewPrinter.defaultPrinter = true

        let failingContext = FailingSaveContext(concurrencyType: .privateQueueConcurrencyType)
        failingContext.persistentStoreCoordinator = persistentContainer.persistentStoreCoordinator
        failingContext.name = "test.failing"
        failingContext.performAndWait {
            let printer = failingContext.object(with: printerID) as! Printer
            printer.hostname = "background change"
            XCTAssertFalse(printerManager.updatePrinter(printer, context: failingContext))
        }

        XCTAssertTrue(viewPrinter.defaultPrinter)
        XCTAssertTrue(persistentContainer.viewContext.hasChanges)
    }

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

    func testPendingDefaultPrinterIsPreservedDuringCloudKitStyleSave() throws {
        let printerID = try insertPrinter(defaultPrinter: false, hostname: "before")
        let viewPrinter = try persistentContainer.viewContext.existingObject(with: printerID) as! Printer
        viewPrinter.defaultPrinter = true
        let cloudKitContext = printerManager.newPrivateContext(writer: "test.cloudKit")
        let merged = expectation(forNotification: .NSManagedObjectContextObjectsDidChange, object: persistentContainer.viewContext) { _ in
            return viewPrinter.recordName == "cloud-record"
        }

        cloudKitContext.performAndWait {
            let printer = cloudKitContext.object(with: printerID) as! Printer
            printer.recordName = "cloud-record"
            printer.recordData = Data([0x01])
            XCTAssertTrue(printerManager.updatePrinter(printer, context: cloudKitContext))
        }

        wait(for: [merged], timeout: 2)
        XCTAssertTrue(viewPrinter.defaultPrinter)
        XCTAssertEqual(viewPrinter.recordName, "cloud-record")
    }

    private func insertPrinter(defaultPrinter: Bool, hostname: String) throws -> NSManagedObjectID {
        let printer = NSEntityDescription.insertNewObject(forEntityName: "Printer", into: persistentContainer.viewContext) as! Printer
        printer.name = "Test printer"
        printer.hostname = hostname
        printer.defaultPrinter = defaultPrinter
        try persistentContainer.viewContext.save()
        return printer.objectID
    }

    private func fetchPrinterState(id: NSManagedObjectID) throws -> PrinterState {
        let context = printerManager.newPrivateContext(writer: "test.fetch")
        var result: PrinterState?
        var caughtError: Error?
        context.performAndWait {
            do {
                let printer = try context.existingObject(with: id) as! Printer
                result = PrinterState(defaultPrinter: printer.defaultPrinter, hostname: printer.hostname, recordName: printer.recordName)
            } catch {
                caughtError = error
            }
        }
        if let caughtError = caughtError {
            throw caughtError
        }
        return result!
    }

//    func testPerformanceExample() throws {
//        // This is an example of a performance test case.
//        measure {
//            // Put the code you want to measure the time of here.
//        }
//    }

}
