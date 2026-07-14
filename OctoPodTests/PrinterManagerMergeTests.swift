import XCTest
@testable import OctoPod

final class PrinterManagerMergeTests: PrinterManagerTestCase {
    func testSiblingContextsPreserveDifferentPrinterProperties() throws {
        let printerID = try insertPrinter(defaultPrinter: false, hostname: "before")
        let defaultWriter = printerManager.newPrivateContext(writer: "test.default")
        let connectionWriter = printerManager.newPrivateContext(writer: "test.connection")

        defaultWriter.performAndWait { (defaultWriter.object(with: printerID) as! Printer).defaultPrinter = true }
        connectionWriter.performAndWait { (connectionWriter.object(with: printerID) as! Printer).hostname = "after" }
        defaultWriter.performAndWait { XCTAssertTrue(printerManager.updatePrinter(defaultWriter.object(with: printerID) as! Printer, context: defaultWriter)) }
        connectionWriter.performAndWait { XCTAssertTrue(printerManager.updatePrinter(connectionWriter.object(with: printerID) as! Printer, context: connectionWriter)) }

        let result = try fetchPrinterState(id: printerID)
        XCTAssertTrue(result.defaultPrinter)
        XCTAssertEqual(result.hostname, "after")
    }

    func testSiblingContextsUseLastSavingWriterForSamePrinterProperty() throws {
        let printerID = try insertPrinter(defaultPrinter: false, hostname: "before")
        let firstWriter = printerManager.newPrivateContext(writer: "test.first")
        let secondWriter = printerManager.newPrivateContext(writer: "test.second")

        firstWriter.performAndWait { (firstWriter.object(with: printerID) as! Printer).hostname = "first" }
        secondWriter.performAndWait { (secondWriter.object(with: printerID) as! Printer).hostname = "second" }
        firstWriter.performAndWait { XCTAssertTrue(printerManager.updatePrinter(firstWriter.object(with: printerID) as! Printer, context: firstWriter)) }
        secondWriter.performAndWait { XCTAssertTrue(printerManager.updatePrinter(secondWriter.object(with: printerID) as! Printer, context: secondWriter)) }

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

    func testSettingsAndCloudKitStylePrivateWritesPreserveUnrelatedProperties() throws {
        let printerID = try insertPrinter(defaultPrinter: false, hostname: "before")
        persistentContainer.viewContext.performAndWait {
            let printer = persistentContainer.viewContext.object(with: printerID) as! Printer
            printer.psuControlInstalled = true
            try! persistentContainer.viewContext.save()
            printer.defaultPrinter = true
        }
        let settings = printerManager.newPrivateContext(writer: "test.settings")
        settings.performAndWait {
            let printer = settings.object(with: printerID) as! Printer
            printer.sdSupport = false
            printer.cameraOrientation = 3
            printer.streamUrl = "/webcam"
            XCTAssertTrue(printerManager.updatePrinter(printer, context: settings))
        }
        let cloud = printerManager.newPrivateContext(writer: "test.cloudKit")
        cloud.performAndWait {
            let printer = cloud.object(with: printerID) as! Printer
            printer.name = "Cloud name"
            printer.hostname = "http://cloud"
            printer.recordName = "record-name"
            printer.recordData = Data([1, 2, 3])
            printer.position = 7
            printer.iCloudUpdate = false
            XCTAssertTrue(printerManager.updatePrinter(printer, context: cloud))
        }

        let state = try freshPrinterState(id: printerID)
        XCTAssertEqual(state.name, "Cloud name")
        XCTAssertEqual(state.hostname, "http://cloud")
        XCTAssertEqual(state.recordName, "record-name")
        XCTAssertFalse(state.iCloudUpdate)
        XCTAssertFalse(state.sdSupport)
        XCTAssertTrue(state.psuControlInstalled)
        XCTAssertTrue((try persistentContainer.viewContext.existingObject(with: printerID) as! Printer).defaultPrinter)
    }

    func testPendingDefaultPrinterIsPreservedDuringCloudKitStyleSave() throws {
        let printerID = try insertPrinter(defaultPrinter: false, hostname: "before")
        let viewPrinter = try persistentContainer.viewContext.existingObject(with: printerID) as! Printer
        viewPrinter.defaultPrinter = true
        let cloudKitContext = printerManager.newPrivateContext(writer: "test.cloudKit")
        let merged = viewContextChangeExpectation { viewPrinter.recordName == "cloud-record" }

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

    func testRepeatedSequentialSiblingPrinterAndCameraSavesRemainConsistent() throws {
        let printerID = try insertPrinter(defaultPrinter: true, hostname: "before")
        let cameraID = try insertMultiCameraInViewContext(printerID: printerID, name: "Stress camera")
        for index in 0..<20 {
            let context = printerManager.newPrivateContext(writer: "test.stress.\(index)")
            context.performAndWait {
                let printer = context.object(with: printerID) as! Printer
                let camera = context.object(with: cameraID) as! MultiCamera
                printer.position = Int16(index)
                camera.streamRatio = "\(index):1"
                XCTAssertTrue(printerManager.updatePrinter(printer, context: context))
                XCTAssertTrue(printerManager.saveObject(camera, context: context))
            }
        }

        XCTAssertEqual(try freshPrinterState(id: printerID).position, 19)
        XCTAssertEqual(try fetchMultiCameraState(id: cameraID).streamRatio, "19:1")
        XCTAssertEqual(try freshMultiCameraCount(named: "Stress camera"), 1)
    }
}
