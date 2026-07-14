import XCTest
import CoreData
@testable import OctoPod

final class PrinterManagerCRUDTests: PrinterManagerTestCase {
    func testPrinterCRUDAndDeletingNonDefaultPreservesDefaultPrinter() throws {
        XCTAssertTrue(printerManager.addPrinter(connectionType: .apiKey, name: "Default", hostname: "http://default", apiKey: "key", username: nil, password: nil, headers: nil, position: 0, iCloudUpdate: true))
        XCTAssertTrue(printerManager.addPrinter(connectionType: .apiKey, name: "Delete me", hostname: "http://delete", apiKey: "key", username: nil, password: nil, headers: nil, position: 1, iCloudUpdate: true))
        let defaultID = try freshPrinterID(named: "Default")
        let deleteID = try freshPrinterID(named: "Delete me")

        persistentContainer.viewContext.performAndWait {
            let printer = persistentContainer.viewContext.object(with: defaultID) as! Printer
            printer.name = "Updated default"
            printer.hostname = "http://updated"
            printer.includeInDashboard = false
            printer.hideCamera = true
            printer.defaultPrinter = true
            XCTAssertTrue(printerManager.updatePrinter(printer))
        }
        let deleteContext = printerManager.newPrivateContext(writer: "test.printerDelete")
        deleteContext.performAndWait { printerManager.deletePrinter(deleteContext.object(with: deleteID) as! Printer, context: deleteContext) }

        XCTAssertThrowsError(try freshPrinterID(named: "Delete me"))
        let state = try freshPrinterState(id: defaultID)
        XCTAssertEqual(state.name, "Updated default")
        XCTAssertEqual(state.hostname, "http://updated")
        XCTAssertFalse(state.includeInDashboard)
        XCTAssertTrue(state.hideCamera)
        XCTAssertTrue(state.defaultPrinter)
    }

    func testPrinterOrderingPersistsAcrossFreshContextFetch() throws {
        for (name, position) in [("One", Int16(0)), ("Two", Int16(1)), ("Three", Int16(2))] {
            XCTAssertTrue(printerManager.addPrinter(connectionType: .apiKey, name: name, hostname: "http://\(name)", apiKey: "key", username: nil, password: nil, headers: nil, position: position, iCloudUpdate: true))
        }
        let ids = try [freshPrinterID(named: "One"), freshPrinterID(named: "Two"), freshPrinterID(named: "Three")]
        let context = printerManager.newPrivateContext(writer: "test.printerOrdering")
        context.performAndWait {
            for (position, id) in [ids[2], ids[0], ids[1]].enumerated() {
                let printer = context.object(with: id) as! Printer
                printer.position = Int16(position)
                XCTAssertTrue(printerManager.updatePrinter(printer, context: context))
            }
        }

        XCTAssertEqual(try freshPrinterNamesInOrder(), ["Three", "One", "Two"])
    }

    func testMultiCameraCRUDThroughSaveObjectAndDeleteObject() throws {
        let printerID = try insertPrinter(defaultPrinter: true, hostname: "before")
        let context = printerManager.newPrivateContext(writer: "test.cameraCRUD")
        var cameraID: NSManagedObjectID?
        var fetchError: Error?
        context.performAndWait {
            let printer = context.object(with: printerID) as! Printer
            XCTAssertTrue(printerManager.addMultiCamera(index: 1, name: "CRUD camera", cameraURL: "http://camera/one", cameraOrientation: 0, streamRatio: "16:9", context: context, printer: printer))
            let request = NSFetchRequest<MultiCamera>(entityName: "MultiCamera")
            request.predicate = NSPredicate(format: "name = %@", "CRUD camera")
            do {
                let camera = try XCTUnwrap(context.fetch(request).first)
                cameraID = camera.objectID
                camera.cameraURL = "http://camera/two"
                XCTAssertTrue(printerManager.saveObject(camera, context: context))
            } catch {
                fetchError = error
            }
        }
        if let fetchError { throw fetchError }
        let savedCameraID = try XCTUnwrap(cameraID)
        XCTAssertEqual(try fetchMultiCameraState(id: savedCameraID).cameraURL, "http://camera/two")
        XCTAssertEqual(try freshMultiCameraCount(named: "CRUD camera"), 1)

        context.performAndWait { printerManager.deleteObject(context.object(with: savedCameraID) as! MultiCamera, context: context) }
        XCTAssertEqual(try freshMultiCameraCount(named: "CRUD camera"), 0)
    }
}
