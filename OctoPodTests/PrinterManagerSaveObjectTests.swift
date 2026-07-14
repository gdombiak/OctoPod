import XCTest
@testable import OctoPod

final class PrinterManagerSaveObjectTests: PrinterManagerTestCase {
    func testSaveObjectPrivateContextSaveMergesMultiCameraIntoViewContext() throws {
        let printerID = try insertPrinter(defaultPrinter: false, hostname: "before")
        let context = printerManager.newPrivateContext(writer: "test.saveObject.success")
        let merged = viewContextChangeExpectation {
            (try? self.multiCamera(named: "Plugin camera"))?.cameraURL == "http://camera.local/stream"
        }

        context.performAndWait {
            let camera = insertMultiCamera(in: context, printerID: printerID, name: "Plugin camera")
            XCTAssertTrue(printerManager.saveObject(camera, context: context))
        }

        wait(for: [merged], timeout: 2)
        XCTAssertEqual(try multiCamera(named: "Plugin camera").cameraURL, "http://camera.local/stream")
    }

    func testSaveObjectFailedPrivateSaveReturnsFalseAndPreservesPendingViewContextEdit() throws {
        let printerID = try insertPrinter(defaultPrinter: false, hostname: "before")
        let viewPrinter = try persistentContainer.viewContext.existingObject(with: printerID) as! Printer
        viewPrinter.defaultPrinter = true
        let failingContext = FailingSaveContext(concurrencyType: .privateQueueConcurrencyType)
        failingContext.persistentStoreCoordinator = persistentContainer.persistentStoreCoordinator
        failingContext.name = "test.saveObject.failing"

        failingContext.performAndWait {
            let camera = insertMultiCamera(in: failingContext, printerID: printerID, name: "Unsaved camera")
            XCTAssertFalse(printerManager.saveObject(camera, context: failingContext))
        }

        XCTAssertTrue(viewPrinter.defaultPrinter)
        XCTAssertTrue(persistentContainer.viewContext.hasChanges)
        XCTAssertThrowsError(try multiCamera(named: "Unsaved camera"))
    }

    func testSaveObjectPrivateSavePreservesUnrelatedPendingViewContextProperty() throws {
        let printerID = try insertPrinter(defaultPrinter: false, hostname: "before")
        let viewPrinter = try persistentContainer.viewContext.existingObject(with: printerID) as! Printer
        viewPrinter.defaultPrinter = true
        let context = printerManager.newPrivateContext(writer: "test.saveObject.pendingViewEdit")
        let merged = viewContextChangeExpectation {
            (try? self.multiCamera(named: "Merged camera"))?.name == "Merged camera"
        }

        context.performAndWait {
            let camera = insertMultiCamera(in: context, printerID: printerID, name: "Merged camera")
            XCTAssertTrue(printerManager.saveObject(camera, context: context))
        }

        wait(for: [merged], timeout: 2)
        XCTAssertTrue(viewPrinter.defaultPrinter)
        XCTAssertEqual(try multiCamera(named: "Merged camera").name, "Merged camera")
    }

    func testSaveObjectRepeatedPrivateSavesDoNotDuplicateMultiCamera() throws {
        let printerID = try insertPrinter(defaultPrinter: false, hostname: "before")
        let context = printerManager.newPrivateContext(writer: "test.saveObject.repeat")
        let merged = viewContextChangeExpectation {
            (try? self.multiCamera(named: "Repeated camera"))?.streamRatio == "4:3"
        }

        context.performAndWait {
            let camera = insertMultiCamera(in: context, printerID: printerID, name: "Repeated camera")
            XCTAssertTrue(printerManager.saveObject(camera, context: context))
            camera.streamRatio = "4:3"
            XCTAssertTrue(printerManager.saveObject(camera, context: context))
        }

        wait(for: [merged], timeout: 2)
        XCTAssertEqual(try multiCameras(named: "Repeated camera").count, 1)
    }

    func testSaveObjectBackgroundMultiCameraUpdatePreservesUnsavedPrinterProperty() throws {
        let printerID = try insertPrinter(defaultPrinter: false, hostname: "before")
        let cameraID = try insertMultiCameraInViewContext(printerID: printerID, name: "Existing camera")
        let viewPrinter = try persistentContainer.viewContext.existingObject(with: printerID) as! Printer
        viewPrinter.defaultPrinter = true
        let context = printerManager.newPrivateContext(writer: "test.saveObject.printerEdit")
        let merged = viewContextChangeExpectation {
            (try? self.persistentContainer.viewContext.existingObject(with: cameraID) as? MultiCamera)?.cameraURL == "http://camera.local/new-stream"
        }

        context.performAndWait {
            let camera = context.object(with: cameraID) as! MultiCamera
            camera.cameraURL = "http://camera.local/new-stream"
            XCTAssertTrue(printerManager.saveObject(camera, context: context))
        }

        wait(for: [merged], timeout: 2)
        XCTAssertTrue(viewPrinter.defaultPrinter)
        XCTAssertEqual((try persistentContainer.viewContext.existingObject(with: cameraID) as! MultiCamera).cameraURL, "http://camera.local/new-stream")
    }

    func testSaveObjectSiblingContextsPreserveDifferentMultiCameraProperties() throws {
        let printerID = try insertPrinter(defaultPrinter: false, hostname: "before")
        let cameraID = try insertMultiCameraInViewContext(printerID: printerID, name: "Sibling camera")
        let first = printerManager.newPrivateContext(writer: "test.saveObject.first")
        let second = printerManager.newPrivateContext(writer: "test.saveObject.second")

        first.performAndWait { (first.object(with: cameraID) as! MultiCamera).cameraURL = "http://camera.local/first" }
        second.performAndWait { (second.object(with: cameraID) as! MultiCamera).streamRatio = "1:1" }
        first.performAndWait { XCTAssertTrue(printerManager.saveObject(first.object(with: cameraID) as! MultiCamera, context: first)) }
        second.performAndWait { XCTAssertTrue(printerManager.saveObject(second.object(with: cameraID) as! MultiCamera, context: second)) }

        let state = try fetchMultiCameraState(id: cameraID)
        XCTAssertEqual(state.cameraURL, "http://camera.local/first")
        XCTAssertEqual(state.streamRatio, "1:1")
    }

    func testSaveObjectSiblingContextsUseLaterWriterForSameMultiCameraProperty() throws {
        let printerID = try insertPrinter(defaultPrinter: false, hostname: "before")
        let cameraID = try insertMultiCameraInViewContext(printerID: printerID, name: "Same-property camera")
        let first = printerManager.newPrivateContext(writer: "test.saveObject.first")
        let second = printerManager.newPrivateContext(writer: "test.saveObject.second")

        first.performAndWait { (first.object(with: cameraID) as! MultiCamera).cameraURL = "http://camera.local/first" }
        second.performAndWait { (second.object(with: cameraID) as! MultiCamera).cameraURL = "http://camera.local/second" }
        first.performAndWait { XCTAssertTrue(printerManager.saveObject(first.object(with: cameraID) as! MultiCamera, context: first)) }
        second.performAndWait { XCTAssertTrue(printerManager.saveObject(second.object(with: cameraID) as! MultiCamera, context: second)) }

        XCTAssertEqual(try fetchMultiCameraState(id: cameraID).cameraURL, "http://camera.local/second")
    }

    func testSaveObjectFailedPrivateSaveDoesNotSaveViewContext() throws {
        let printerID = try insertPrinter(defaultPrinter: false, hostname: "before")
        let failingContext = FailingSaveContext(concurrencyType: .privateQueueConcurrencyType)
        failingContext.persistentStoreCoordinator = persistentContainer.persistentStoreCoordinator
        failingContext.name = "test.saveObject.noViewSave"
        let viewContextSave = expectation(forNotification: .NSManagedObjectContextDidSave, object: persistentContainer.viewContext)
        viewContextSave.isInverted = true

        failingContext.performAndWait {
            let camera = insertMultiCamera(in: failingContext, printerID: printerID, name: "Failed camera")
            XCTAssertFalse(printerManager.saveObject(camera, context: failingContext))
        }

        wait(for: [viewContextSave], timeout: 0.2)
    }

    func testSaveObjectSequentialBackgroundSavesMergeMultiCameraIntoViewContext() throws {
        let printerID = try insertPrinter(defaultPrinter: false, hostname: "before")
        let cameraID = try insertMultiCameraInViewContext(printerID: printerID, name: "Sequential camera")
        let first = printerManager.newPrivateContext(writer: "test.saveObject.sequentialFirst")
        let second = printerManager.newPrivateContext(writer: "test.saveObject.sequentialSecond")
        let merged = viewContextChangeExpectation {
            guard let camera = try? self.persistentContainer.viewContext.existingObject(with: cameraID) as? MultiCamera else { return false }
            return camera.cameraURL == "http://camera.local/first" && camera.streamRatio == "1:1"
        }

        first.performAndWait {
            let camera = first.object(with: cameraID) as! MultiCamera
            camera.cameraURL = "http://camera.local/first"
            XCTAssertTrue(printerManager.saveObject(camera, context: first))
        }
        second.performAndWait {
            let camera = second.object(with: cameraID) as! MultiCamera
            camera.streamRatio = "1:1"
            XCTAssertTrue(printerManager.saveObject(camera, context: second))
        }

        wait(for: [merged], timeout: 2)
        let camera = try persistentContainer.viewContext.existingObject(with: cameraID) as! MultiCamera
        XCTAssertEqual(camera.cameraURL, "http://camera.local/first")
        XCTAssertEqual(camera.streamRatio, "1:1")
    }
}
