import XCTest
import CoreData
@testable import OctoPod

final class OctoPrintClientPluginSyncTests: PrinterManagerTestCase {
    private final class AddResultPrinterManager: PrinterManager {
        private var multiCameraResults: [Bool] = []
        private var enclosureInputResults: [Bool] = []
        private var enclosureOutputResults: [Bool] = []

        func configure(multiCameraResults: [Bool], enclosureInputResults: [Bool], enclosureOutputResults: [Bool]) {
            self.multiCameraResults = multiCameraResults
            self.enclosureInputResults = enclosureInputResults
            self.enclosureOutputResults = enclosureOutputResults
        }

        override func addMultiCamera(index: Int16, name: String, cameraURL: String, cameraOrientation: Int16, streamRatio: String, context: NSManagedObjectContext, printer: Printer) -> Bool {
            guard nextResult(from: &multiCameraResults, operation: "addMultiCamera") else { return false }
            return super.addMultiCamera(index: index, name: name, cameraURL: cameraURL, cameraOrientation: cameraOrientation, streamRatio: streamRatio, context: context, printer: printer)
        }

        override func addEnclosureInput(index: Int16, type: String, label: String, useFahrenheit: Bool, context: NSManagedObjectContext, printer: Printer) -> Bool {
            guard nextResult(from: &enclosureInputResults, operation: "addEnclosureInput") else { return false }
            return super.addEnclosureInput(index: index, type: type, label: label, useFahrenheit: useFahrenheit, context: context, printer: printer)
        }

        override func addEnclosureOutput(index: Int16, type: String, label: String, context: NSManagedObjectContext, printer: Printer) -> Bool {
            guard nextResult(from: &enclosureOutputResults, operation: "addEnclosureOutput") else { return false }
            return super.addEnclosureOutput(index: index, type: type, label: label, context: context, printer: printer)
        }

        private func nextResult(from results: inout [Bool], operation: String) -> Bool {
            precondition(!results.isEmpty, "Missing mocked result for \(operation)")
            return results.removeFirst()
        }
    }

    private final class SettingsDelegate: OctoPrintSettingsDelegate {
        var cameraURLs: [[String]] = []
        var enclosureInputsChangedCount = 0
        var enclosureOutputsChangedCount = 0

        func camerasChanged(camerasURLs: Array<String>) {
            cameraURLs.append(camerasURLs)
        }

        func enclosureInputsChanged() {
            enclosureInputsChangedCount += 1
        }

        func enclosureOutputsChanged() {
            enclosureOutputsChangedCount += 1
        }
    }

    private var addResultPrinterManager: AddResultPrinterManager!
    private var client: OctoPrintClient!
    private var settingsDelegate: SettingsDelegate!

    override func setUpWithError() throws {
        try super.setUpWithError()
        addResultPrinterManager = AddResultPrinterManager(managedObjectContext: persistentContainer.viewContext, persistentContainer: persistentContainer)
        printerManager = addResultPrinterManager
        client = OctoPrintClient(printerManager: addResultPrinterManager, appConfiguration: AppConfiguration())
        settingsDelegate = SettingsDelegate()
        client.octoPrintSettingsDelegates.append(settingsDelegate)
    }

    override func tearDownWithError() throws {
        settingsDelegate = nil
        client = nil
        addResultPrinterManager = nil
        try super.tearDownWithError()
    }

    func testSuccessfulPluginAddsNotifyEachModelChangeOnce() throws {
        addResultPrinterManager.configure(multiCameraResults: [true], enclosureInputResults: [true], enclosureOutputResults: [true])
        let printerID = try insertPrinter(defaultPrinter: true, hostname: "success")

        client.updatePrinterFromMultiCamPlugin(printerID: printerID, plugins: multiCamPlugins(profiles: [multiCamProfile(name: "camera-success", url: "http://camera/success")]))
        client.updatePrinterFromEnclosurePlugin(printerID: printerID, plugins: enclosurePlugins(inputs: [enclosureInput(index: 1, label: "input-success")], outputs: [enclosureOutput(index: 1, label: "output-success")]))

        XCTAssertEqual(settingsDelegate.cameraURLs, [["http://camera/success"]])
        XCTAssertEqual(settingsDelegate.enclosureInputsChangedCount, 1)
        XCTAssertEqual(settingsDelegate.enclosureOutputsChangedCount, 1)
        XCTAssertEqual(try freshStrings(entityName: "MultiCamera", key: "name"), ["camera-success"])
        XCTAssertEqual(try freshStrings(entityName: "EnclosureInput", key: "label"), ["input-success"])
        XCTAssertEqual(try freshStrings(entityName: "EnclosureOutput", key: "label"), ["output-success"])
    }

    func testFailedPluginAddsDoNotNotifyOrPersistModels() throws {
        addResultPrinterManager.configure(multiCameraResults: [false], enclosureInputResults: [false], enclosureOutputResults: [false])
        let printerID = try insertPrinter(defaultPrinter: true, hostname: "failure")

        client.updatePrinterFromMultiCamPlugin(printerID: printerID, plugins: multiCamPlugins(profiles: [multiCamProfile(name: "camera-failed", url: "http://camera/failed")]))
        client.updatePrinterFromEnclosurePlugin(printerID: printerID, plugins: enclosurePlugins(inputs: [enclosureInput(index: 1, label: "input-failed")], outputs: [enclosureOutput(index: 1, label: "output-failed")]))

        XCTAssertTrue(settingsDelegate.cameraURLs.isEmpty)
        XCTAssertEqual(settingsDelegate.enclosureInputsChangedCount, 0)
        XCTAssertEqual(settingsDelegate.enclosureOutputsChangedCount, 0)
        XCTAssertEqual(try freshStrings(entityName: "MultiCamera", key: "name"), [])
        XCTAssertEqual(try freshStrings(entityName: "EnclosureInput", key: "label"), [])
        XCTAssertEqual(try freshStrings(entityName: "EnclosureOutput", key: "label"), [])
    }

    func testFailedPluginAddsDoNotPreventLaterIndependentAdds() throws {
        addResultPrinterManager.configure(multiCameraResults: [false, true], enclosureInputResults: [false, true], enclosureOutputResults: [false, true])
        let printerID = try insertPrinter(defaultPrinter: true, hostname: "mixed")

        client.updatePrinterFromMultiCamPlugin(printerID: printerID, plugins: multiCamPlugins(profiles: [
            multiCamProfile(name: "camera-failed", url: "http://camera/failed"),
            multiCamProfile(name: "camera-success", url: "http://camera/success")
        ]))
        client.updatePrinterFromEnclosurePlugin(printerID: printerID, plugins: enclosurePlugins(inputs: [
            enclosureInput(index: 1, label: "input-failed"),
            enclosureInput(index: 2, label: "input-success")
        ], outputs: [
            enclosureOutput(index: 1, label: "output-failed"),
            enclosureOutput(index: 2, label: "output-success")
        ]))

        XCTAssertEqual(settingsDelegate.cameraURLs, [["http://camera/success"]])
        XCTAssertEqual(settingsDelegate.enclosureInputsChangedCount, 1)
        XCTAssertEqual(settingsDelegate.enclosureOutputsChangedCount, 1)
        XCTAssertEqual(try freshStrings(entityName: "MultiCamera", key: "name"), ["camera-success"])
        XCTAssertEqual(try freshStrings(entityName: "EnclosureInput", key: "label"), ["input-success"])
        XCTAssertEqual(try freshStrings(entityName: "EnclosureOutput", key: "label"), ["output-success"])
    }

    private func multiCamPlugins(profiles: [NSDictionary]) -> NSDictionary {
        return [Plugins.MULTICAM: ["multicam_profiles": profiles] as NSDictionary] as NSDictionary
    }

    private func enclosurePlugins(inputs: [NSDictionary], outputs: [NSDictionary]) -> NSDictionary {
        return [Plugins.ENCLOSURE: ["rpi_inputs": inputs, "rpi_outputs": outputs] as NSDictionary] as NSDictionary
    }

    private func multiCamProfile(name: String, url: String) -> NSDictionary {
        return ["URL": url, "flipH": false, "flipV": false, "rotate90": false, "name": name, "streamRatio": "16:9"] as NSDictionary
    }

    private func enclosureInput(index: Int16, label: String) -> NSDictionary {
        return ["index_id": index, "input_type": "temperature", "label": label, "use_fahrenheit": false] as NSDictionary
    }

    private func enclosureOutput(index: Int16, label: String) -> NSDictionary {
        return ["index_id": index, "output_type": "regular", "label": label, "hide_btn_ui": false] as NSDictionary
    }

    private func freshStrings(entityName: String, key: String) throws -> [String] {
        let context = printerManager.newPrivateContext(writer: "test.pluginSync.fetch")
        var values: [String] = []
        var caughtError: Error?
        context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            request.sortDescriptors = [NSSortDescriptor(key: "index_id", ascending: true)]
            do {
                values = try context.fetch(request).compactMap { $0.value(forKey: key) as? String }
            } catch {
                caughtError = error
            }
        }
        if let caughtError { throw caughtError }
        return values
    }
}
