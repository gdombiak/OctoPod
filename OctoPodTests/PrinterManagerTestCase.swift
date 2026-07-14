import XCTest
import CoreData
@testable import OctoPod

class PrinterManagerTestCase: XCTestCase {
    struct PrinterState {
        let defaultPrinter: Bool
        let hostname: String
        let recordName: String?
    }

    enum TestSaveError: Error { case forced }

    final class FailingSaveContext: NSManagedObjectContext, @unchecked Sendable {
        override func save() throws { throw TestSaveError.forced }
    }

    var persistentContainer: NSPersistentContainer!
    var printerManager: PrinterManager!

    override func setUpWithError() throws {
        let modelURL = try XCTUnwrap(Bundle(for: Printer.self).url(forResource: "OctoPod", withExtension: "momd"))
        let model = try XCTUnwrap(NSManagedObjectModel(contentsOf: modelURL))
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

    func insertPrinter(defaultPrinter: Bool, hostname: String) throws -> NSManagedObjectID {
        let printer = NSEntityDescription.insertNewObject(forEntityName: "Printer", into: persistentContainer.viewContext) as! Printer
        printer.name = "Test printer"
        printer.hostname = hostname
        printer.defaultPrinter = defaultPrinter
        try persistentContainer.viewContext.save()
        return printer.objectID
    }

    func fetchPrinterState(id: NSManagedObjectID) throws -> PrinterState {
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
        if let caughtError { throw caughtError }
        guard let result else { throw NSError(domain: "OctoPodTests", code: 2) }
        return result
    }

    func freshPrinterID(named name: String) throws -> NSManagedObjectID {
        let context = printerManager.newPrivateContext(writer: "test.fetchPrinter")
        var result: NSManagedObjectID?
        context.performAndWait {
            let request = NSFetchRequest<Printer>(entityName: "Printer")
            request.predicate = NSPredicate(format: "name = %@", name)
            result = try? context.fetch(request).first?.objectID
        }
        guard let result else { throw NSError(domain: "OctoPodTests", code: 2) }
        return result
    }

    func freshPrinterNamesInOrder() throws -> [String] {
        let context = printerManager.newPrivateContext(writer: "test.fetchOrder")
        var names: [String] = []
        context.performAndWait {
            let request = NSFetchRequest<Printer>(entityName: "Printer")
            request.sortDescriptors = [NSSortDescriptor(key: "position", ascending: true)]
            names = (try? context.fetch(request).map(\.name)) ?? []
        }
        return names
    }

    func freshPrinterState(id: NSManagedObjectID) throws -> (name: String, hostname: String, includeInDashboard: Bool, hideCamera: Bool, defaultPrinter: Bool, recordName: String?, iCloudUpdate: Bool, sdSupport: Bool, psuControlInstalled: Bool, position: Int16) {
        let context = printerManager.newPrivateContext(writer: "test.fetchPrinterState")
        var state: (name: String, hostname: String, includeInDashboard: Bool, hideCamera: Bool, defaultPrinter: Bool, recordName: String?, iCloudUpdate: Bool, sdSupport: Bool, psuControlInstalled: Bool, position: Int16)?
        context.performAndWait {
            if let printer = try? context.existingObject(with: id) as? Printer {
                state = (printer.name, printer.hostname, printer.includeInDashboard, printer.hideCamera, printer.defaultPrinter, printer.recordName, printer.iCloudUpdate, printer.sdSupport, printer.psuControlInstalled, printer.position)
            }
        }
        return try XCTUnwrap(state)
    }

    func insertMultiCamera(in context: NSManagedObjectContext, printerID: NSManagedObjectID, name: String) -> MultiCamera {
        let printer = context.object(with: printerID) as! Printer
        let camera = NSEntityDescription.insertNewObject(forEntityName: "MultiCamera", into: context) as! MultiCamera
        camera.index_id = 1
        camera.name = name
        camera.cameraURL = "http://camera.local/stream"
        camera.cameraOrientation = 0
        camera.streamRatio = "16:9"
        camera.printer = printer
        return camera
    }

    func multiCamera(named name: String) throws -> MultiCamera {
        guard let camera = try multiCameras(named: name).first else {
            throw NSError(domain: "OctoPodTests", code: 1)
        }
        return camera
    }

    func multiCameras(named name: String) throws -> [MultiCamera] {
        let request = NSFetchRequest<MultiCamera>(entityName: "MultiCamera")
        request.predicate = NSPredicate(format: "name = %@", name)
        return try persistentContainer.viewContext.fetch(request)
    }

    func insertMultiCameraInViewContext(printerID: NSManagedObjectID, name: String) throws -> NSManagedObjectID {
        let camera = insertMultiCamera(in: persistentContainer.viewContext, printerID: printerID, name: name)
        try persistentContainer.viewContext.save()
        return camera.objectID
    }

    func fetchMultiCameraState(id: NSManagedObjectID) throws -> (cameraURL: String, streamRatio: String) {
        let context = printerManager.newPrivateContext(writer: "test.fetchCamera")
        var result: (cameraURL: String, streamRatio: String)?
        var caughtError: Error?
        context.performAndWait {
            do {
                let camera = try context.existingObject(with: id) as! MultiCamera
                result = (camera.cameraURL, camera.streamRatio)
            } catch {
                caughtError = error
            }
        }
        if let caughtError { throw caughtError }
        return try XCTUnwrap(result)
    }

    func freshMultiCameraCount(named name: String) throws -> Int {
        let context = printerManager.newPrivateContext(writer: "test.fetchCameraCount")
        var count = 0
        context.performAndWait {
            let request = NSFetchRequest<MultiCamera>(entityName: "MultiCamera")
            request.predicate = NSPredicate(format: "name = %@", name)
            count = (try? context.count(for: request)) ?? 0
        }
        return count
    }

    func viewContextChangeExpectation(_ condition: @escaping () -> Bool) -> XCTestExpectation {
        expectation(forNotification: .NSManagedObjectContextObjectsDidChange, object: persistentContainer.viewContext) { _ in
            condition()
        }
    }
}
