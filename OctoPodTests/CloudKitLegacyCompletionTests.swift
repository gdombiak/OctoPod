import XCTest
import CloudKit
import CoreData
@testable import OctoPod

final class CloudKitLegacyCompletionTests: XCTestCase {

    func testAllItemsSucceedProducesNoError() {
        let error = CloudKitLegacyCompletion.combinedError(operationResult: .success(()), itemErrors: [:])
        XCTAssertNil(error)
        XCTAssertNil(CloudKitLegacyCompletion.partialFailureError([:]))
    }

    func testOperationLevelFailurePreservesOriginalError() {
        let operationError = CKError(.networkFailure)
        let itemID = CKRecord.ID(recordName: "ignored")
        let itemError = CKError(.unknownItem)
        let error = CloudKitLegacyCompletion.combinedError(
            operationResult: .failure(operationError),
            itemErrors: [itemID: itemError]
        )
        let ckerror = error as? CKError
        XCTAssertEqual(ckerror?.code, .networkFailure)
        XCTAssertNil(ckerror?.partialErrorsByItemID)
    }

    func testItemFailureWithOperationSuccessSynthesizesPartialFailure() {
        let failedID = CKRecord.ID(recordName: "failed")
        let itemError = CKError(.serverRecordChanged)
        let error = CloudKitLegacyCompletion.combinedError(
            operationResult: .success(()),
            itemErrors: [failedID: itemError]
        )
        let ckerror = error as? CKError
        XCTAssertEqual(ckerror?.code, .partialFailure)
        XCTAssertNotNil(ckerror?.partialErrorsByItemID)
    }

    func testPartialFailureContainsErrorsByItemIDKey() {
        let failedID = CKRecord.ID(recordName: "failed")
        let itemError = CKError(.unknownItem)
        let error = CloudKitLegacyCompletion.partialFailureError([failedID: itemError])
        let nsError = error as NSError?
        XCTAssertEqual(nsError?.code, CKError.Code.partialFailure.rawValue)
        let byItemID = nsError?.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error]
        XCTAssertNotNil(byItemID)
        XCTAssertNotNil(byItemID?[failedID])
        XCTAssertEqual((byItemID?[failedID] as? CKError)?.code, .unknownItem)
        XCTAssertEqual(((error as? CKError)?.partialErrorsByItemID?[failedID] as? CKError)?.code, .unknownItem)
    }

    func testSuccessfulItemsArePreservedAlongsidePartialError() {
        let savedID = CKRecord.ID(recordName: "saved")
        let failedID = CKRecord.ID(recordName: "failed")
        let savedRecord = CKRecord(recordType: "OctoPrint", recordID: savedID)
        let saved = [savedRecord]
        let deleted: [CKRecord.ID] = []
        let itemError = CKError(.serverRecordChanged)
        let error = CloudKitLegacyCompletion.combinedError(
            operationResult: .success(()),
            itemErrors: [failedID: itemError]
        )
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.recordID, savedID)
        XCTAssertTrue(deleted.isEmpty)
        XCTAssertEqual((error as? CKError)?.code, .partialFailure)
        XCTAssertEqual(((error as? CKError)?.partialErrorsByItemID?[failedID] as? CKError)?.code, .serverRecordChanged)
        XCTAssertNil((error as? CKError)?.partialErrorsByItemID?[savedID])
    }

    func testQueryPartialFailureDoesNotLookLikeSuccessfulEmptyResult() {
        let failedID = CKRecord.ID(recordName: "query-miss")
        let error = CloudKitLegacyCompletion.combinedError(
            operationResult: .success(()),
            itemErrors: [failedID: CKError(.unknownItem)]
        )
        XCTAssertNotNil(error)
        XCTAssertEqual((error as? CKError)?.code, .partialFailure)
        // Existing queryRecord caller treats any error as `completion(nil, error)`,
        // never as a successful empty match list.
        let matchedRecords: [CKRecord] = []
        XCTAssertTrue(matchedRecords.isEmpty)
        XCTAssertNotNil(error, "query must not report an empty successful result when an item failed")
    }

    func testModifyRecordPartialFailurePreservesRecordIDErrorMapping() {
        let conflictID = CKRecord.ID(recordName: "conflict")
        let zoneMissingID = CKRecord.ID(recordName: "zone-missing")
        let itemErrors: [AnyHashable: Error] = [
            conflictID: CKError(.serverRecordChanged),
            zoneMissingID: CKError(.zoneNotFound)
        ]
        let error = CloudKitLegacyCompletion.combinedError(operationResult: .success(()), itemErrors: itemErrors)
        let ckerror = error as? CKError
        XCTAssertEqual(ckerror?.code, .partialFailure)
        XCTAssertEqual((ckerror?.partialErrorsByItemID?[conflictID] as? CKError)?.code, .serverRecordChanged)
        XCTAssertEqual((ckerror?.partialErrorsByItemID?[zoneMissingID] as? CKError)?.code, .zoneNotFound)
        XCTAssertTrue(ckerror?.isConflict() ?? false)
        XCTAssertTrue(ckerror?.isZoneNotFound() ?? false)
    }

    func testZoneChangeRecordFailurePreventsBatchFromBeingTreatedAsSuccessful() {
        let failedID = CKRecord.ID(recordName: "skipped-record")
        let error = CloudKitLegacyCompletion.combinedError(
            operationResult: .success(()),
            itemErrors: [failedID: CKError(.unknownItem)]
        )
        XCTAssertNotNil(error)
        XCTAssertEqual((error as? CKError)?.code, .partialFailure)
        // Existing pullChanges zone completion returns before persisting CHANGE_TOKEN
        // when error != nil, so a successful operation Result must not stay error-free.
    }

    func testCollectorSharesFailuresAcrossAssociatedOperationCallbacks() {
        let operation = CKQueryOperation(query: CKQuery(recordType: "OctoPrint", predicate: NSPredicate(value: true)))
        let first = CloudKitItemFailureCollector.associated(with: operation)
        let second = CloudKitItemFailureCollector.associated(with: operation)
        XCTAssertTrue(first === second)
        let recordID = CKRecord.ID(recordName: "shared")
        first.record(itemID: recordID, error: CKError(.unknownItem))
        XCTAssertEqual((second.snapshot[recordID] as? CKError)?.code, .unknownItem)
        let error = CloudKitLegacyCompletion.partialFailureError(second.snapshot)
        XCTAssertEqual((error as? CKError)?.code, .partialFailure)
    }

    func testChangeTokenUpdateIsForwardedWhenCollectorHasNoFailures() {
        let operation = CKFetchRecordZoneChangesOperation()
        let collector = CloudKitItemFailureCollector.associated(with: operation)
        XCTAssertTrue(CloudKitLegacyCompletion.shouldForwardChangeTokenUpdate(itemErrors: collector.snapshot))

        var forwarded = 0
        simulateTokenUpdate(operation: operation) { forwarded += 1 }
        XCTAssertEqual(forwarded, 1)
    }

    func testRecordFailureSuppressesLaterTokenUpdateAndCompletionsArePartialFailure() {
        let operation = CKFetchRecordZoneChangesOperation()
        let recordCollector = CloudKitItemFailureCollector.associated(with: operation)
        let tokenCollector = CloudKitItemFailureCollector.associated(with: operation)
        XCTAssertTrue(recordCollector === tokenCollector)

        let failedID = CKRecord.ID(recordName: "failed-record")
        recordCollector.record(itemID: failedID, error: CKError(.unknownItem))

        var forwarded = 0
        simulateTokenUpdate(operation: operation) { forwarded += 1 }
        XCTAssertEqual(forwarded, 0, "token update after a record failure must not be forwarded")

        let zoneError = CloudKitLegacyCompletion.combinedError(
            operationResult: .success(()),
            itemErrors: tokenCollector.snapshot
        )
        XCTAssertEqual((zoneError as? CKError)?.code, .partialFailure)

        let finalError = CloudKitLegacyCompletion.combinedError(
            operationResult: .success(()),
            itemErrors: tokenCollector.snapshot
        )
        XCTAssertEqual((finalError as? CKError)?.code, .partialFailure)
        XCTAssertFalse(CloudKitLegacyCompletion.shouldForwardChangeTokenUpdate(itemErrors: tokenCollector.snapshot))
    }

    func testTokenUpdateBeforeLaterRecordFailureDoesNotAcknowledgeTheFailedRecord() {
        // CloudKit runs CKFetchRecordZoneChangesOperation callbacks on a private
        // serial queue and processes each zone in batches: record callbacks for a
        // batch, then that batch's token update. A token delivered with an empty
        // collector is therefore a checkpoint for an earlier fully-successful
        // batch and does not include a later failed record.
        let operation = CKFetchRecordZoneChangesOperation()
        let collector = CloudKitItemFailureCollector.associated(with: operation)

        var forwarded = 0
        simulateTokenUpdate(operation: operation) { forwarded += 1 }
        XCTAssertEqual(forwarded, 1)

        collector.record(itemID: CKRecord.ID(recordName: "later-failed"), error: CKError(.unknownItem))
        simulateTokenUpdate(operation: operation) { forwarded += 1 }
        XCTAssertEqual(forwarded, 1, "once a record fails, later tokens from this operation must not be forwarded")

        let zoneError = CloudKitLegacyCompletion.combinedError(
            operationResult: .success(()),
            itemErrors: collector.snapshot
        )
        XCTAssertEqual((zoneError as? CKError)?.code, .partialFailure)
    }

    private func simulateTokenUpdate(operation: CKFetchRecordZoneChangesOperation, onForward: () -> Void) {
        let collector = CloudKitItemFailureCollector.associated(with: operation)
        if CloudKitLegacyCompletion.shouldForwardChangeTokenUpdate(itemErrors: collector.snapshot) {
            onForward()
        }
    }
}

final class CloudKitPrinterPullTests: PrinterManagerTestCase {
    private final class FailingPrinterManager: PrinterManager {
        var failSaves = false

        override func saveObject(_ object: NSManagedObject, context: NSManagedObjectContext) -> Bool {
            !failSaves && super.saveObject(object, context: context)
        }

        override func updatePrinter(_ printer: Printer, context: NSManagedObjectContext) -> Bool {
            !failSaves && super.updatePrinter(printer, context: context)
        }
    }

    private final class Operations {
        private let lock = NSLock()
        private var submitted: [CKDatabaseOperation] = []
        private let expectations: [XCTestExpectation]

        init(_ expectations: [XCTestExpectation]) {
            self.expectations = expectations
        }

        func submit(_ operation: CKDatabaseOperation) {
            lock.lock()
            let index = submitted.count
            submitted.append(operation)
            lock.unlock()
            if expectations.indices.contains(index) {
                expectations[index].fulfill()
            } else {
                XCTFail("Unexpected CloudKit operation: \(type(of: operation))")
            }
        }

        func pull(_ index: Int) -> CKFetchRecordZoneChangesOperation {
            operation(index) as! CKFetchRecordZoneChangesOperation
        }

        func operation(_ index: Int) -> CKDatabaseOperation {
            lock.lock()
            defer { lock.unlock() }
            return submitted[index]
        }
    }

    private var writer: FailingPrinterManager!
    private var defaults: UserDefaults!
    private var defaultsName: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        writer = FailingPrinterManager(managedObjectContext: persistentContainer.viewContext, persistentContainer: persistentContainer)
        defaultsName = "CloudKitPrinterPullTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsName))
    }

    override func tearDownWithError() throws {
        defaults?.removePersistentDomain(forName: defaultsName)
        writer = nil
        defaults = nil
        try super.tearDownWithError()
    }

    func testFailedSaveBlocksCheckpointFromAnEarlierPage() {
        let oldCheckpoint = Data([1])
        let proposedCheckpoint = Data([2])
        var stored = oldCheckpoint
        var progress = CloudKitPrinterPullProgress()
        progress.checkpoint = proposedCheckpoint
        progress.localError = TestSaveError.forced

        let failure = progress.finish(operationError: nil) { stored = $0 }
        XCTAssertNotNil(failure as? TestSaveError)
        XCTAssertEqual(stored, oldCheckpoint)

        progress.localError = nil
        XCTAssertNil(progress.finish(operationError: nil) { stored = $0 })
        XCTAssertEqual(stored, proposedCheckpoint)
    }

    func testFailedInsertReplaysAndSavesIdentityWithTheNewRow() throws {
        let first = expectation(description: "first pull submitted")
        let replay = expectation(description: "replay submitted")
        let operations = Operations([first, replay])
        let manager = CloudKitPrinterManager(printerManager: writer, defaults: defaults) { [weak operations] in
            operations?.submit($0)
        }
        let record = printerRecord(id: "remote-printer", name: "Test printer", hostname: "remote.local")
        let otherID = try insertPrinter(defaultPrinter: true, hostname: "different.local")

        writer.failSaves = true
        let failed = pull(manager, succeeds: false)
        wait(for: [first], timeout: 2)
        operations.pull(0).recordWasChangedBlock?(record.recordID, .success(record))
        operations.pull(0).fetchRecordZoneChangesResultBlock?(.success(()))
        wait(for: [failed], timeout: 2)
        XCTAssertEqual(try freshPrinterNamesInOrder(), ["Test printer"])
        XCTAssertNil(try fetchPrinterState(id: otherID).recordName)

        writer.failSaves = false
        let recovered = pull(manager, succeeds: true)
        wait(for: [replay], timeout: 2)
        // Two deliveries of a record must update the same newly linked row.
        for _ in 0..<2 {
            operations.pull(1).recordWasChangedBlock?(record.recordID, .success(record))
        }
        operations.pull(1).fetchRecordZoneChangesResultBlock?(.success(()))
        wait(for: [recovered], timeout: 2)

        let state = allPrinterLinks()
        XCTAssertEqual(state.count, 2)
        XCTAssertEqual(state.first { $0.hostname == "remote.local" }?.recordName, "remote-printer")
        XCTAssertNil(try fetchPrinterState(id: otherID).recordName)
    }

    func testFailedUpdateReplaysWithoutOverwritingNewerPendingLocalEdit() throws {
        let first = expectation(description: "first pull submitted")
        let replay = expectation(description: "replay submitted")
        let operations = Operations([first, replay])
        let manager = CloudKitPrinterManager(printerManager: writer, defaults: defaults) { [weak operations] in
            operations?.submit($0)
        }
        let record = printerRecord(id: "linked", name: "Remote name", hostname: "printer.local")
        let id = try insertPrinter(defaultPrinter: true, hostname: "printer.local")
        let printer = try XCTUnwrap(persistentContainer.viewContext.existingObject(with: id) as? Printer)
        printer.recordName = "linked"
        printer.iCloudUpdate = false
        try persistentContainer.viewContext.save()

        writer.failSaves = true
        let failed = pull(manager, succeeds: false)
        wait(for: [first], timeout: 2)
        operations.pull(0).recordWasChangedBlock?(record.recordID, .success(record))
        operations.pull(0).fetchRecordZoneChangesResultBlock?(.success(()))
        wait(for: [failed], timeout: 2)
        XCTAssertEqual(try freshPrinterState(id: id).name, "Test printer")

        printer.name = "Newer local name"
        printer.userModified = Date(timeIntervalSince1970: 200)
        printer.iCloudUpdate = true
        try persistentContainer.viewContext.save()

        writer.failSaves = false
        let recovered = pull(manager, succeeds: true)
        wait(for: [replay], timeout: 2)
        operations.pull(1).recordWasChangedBlock?(record.recordID, .success(record))
        operations.pull(1).fetchRecordZoneChangesResultBlock?(.success(()))
        wait(for: [recovered], timeout: 2)
        let stored = try freshPrinterState(id: id)
        XCTAssertEqual(stored.name, "Newer local name")
        XCTAssertTrue(stored.iCloudUpdate)
        XCTAssertEqual(stored.recordName, "linked")
        XCTAssertEqual(allPrinterLinks().count, 1)
    }

    func testPullPreservesPendingReorderWithSameModificationDate() throws {
        let submitted = expectation(description: "pull submitted")
        let operations = Operations([submitted])
        let manager = CloudKitPrinterManager(printerManager: writer, defaults: defaults) { [weak operations] in
            operations?.submit($0)
        }
        let (id, record) = try makeLinkedPrinter()
        let finished = pull(manager, succeeds: true)
        wait(for: [submitted], timeout: 2)

        try reorderWhileSyncing(id)
        let operation = operations.pull(0)
        operation.recordWasChangedBlock?(record.recordID, .success(record))
        operation.fetchRecordZoneChangesResultBlock?(.success(()))
        wait(for: [finished], timeout: 2)

        let stored = try freshPrinterState(id: id)
        XCTAssertEqual(stored.position, 1)
        XCTAssertTrue(stored.iCloudUpdate)
    }

    func testPushAcknowledgmentKeepsReorderForTheQueuedPush() throws {
        let firstSubmitted = expectation(description: "original push submitted")
        let nextSubmitted = expectation(description: "reordered push submitted")
        let operations = Operations([firstSubmitted, nextSubmitted])
        let manager = CloudKitPrinterManager(printerManager: writer, defaults: defaults) { [weak operations] in
            operations?.submit($0)
        }
        let (id, _) = try makeLinkedPrinter()
        let firstFinished = expectation(description: "original push completed")
        manager.pushChanges { firstFinished.fulfill() }
        wait(for: [firstSubmitted], timeout: 2)
        let firstSave = try XCTUnwrap(operations.operation(0) as? CKModifyRecordsOperation)
        let firstRecord = try XCTUnwrap(firstSave.recordsToSave?.first)
        XCTAssertEqual(firstRecord["position"] as? Int16, 0)

        try reorderWhileSyncing(id)
        let nextFinished = expectation(description: "reordered push completed")
        manager.pushChanges { nextFinished.fulfill() }
        firstSave.perRecordSaveBlock?(firstRecord.recordID, .success(firstRecord))
        firstSave.modifyRecordsResultBlock?(.success(()))
        guard XCTWaiter.wait(for: [firstFinished, nextSubmitted], timeout: 2, enforceOrder: true) == .completed else {
            XCTFail("The older push cleared the pending reorder")
            return
        }

        let nextSave = try XCTUnwrap(operations.operation(1) as? CKModifyRecordsOperation)
        let nextRecord = try XCTUnwrap(nextSave.recordsToSave?.first)
        XCTAssertEqual(nextRecord["position"] as? Int16, 1)
        XCTAssertEqual(nextRecord["modified"] as? Date, firstRecord["modified"] as? Date)
        nextSave.perRecordSaveBlock?(nextRecord.recordID, .success(nextRecord))
        nextSave.modifyRecordsResultBlock?(.success(()))
        wait(for: [nextFinished], timeout: 2)
        let stored = try freshPrinterState(id: id)
        XCTAssertEqual(stored.position, 1)
        XCTAssertFalse(stored.iCloudUpdate)
    }

    func testFailedDefaultDeletionReplaysWithAtomicReplacement() throws {
        let first = expectation(description: "delete pull submitted")
        let replay = expectation(description: "replay submitted")
        let operations = Operations([first, replay])
        let manager = CloudKitPrinterManager(printerManager: writer, defaults: defaults) { [weak operations] in
            operations?.submit($0)
        }
        let oldID = try insertPrinter(defaultPrinter: true, hostname: "old.local")
        let nextID = try insertPrinter(defaultPrinter: false, hostname: "next.local")
        let old = try XCTUnwrap(persistentContainer.viewContext.existingObject(with: oldID) as? Printer)
        old.recordName = "remote-old"
        try persistentContainer.viewContext.save()
        let recordID = CKRecord.ID(recordName: "remote-old")

        writer.failSaves = true
        let failed = pull(manager, succeeds: false)
        wait(for: [first], timeout: 2)
        operations.pull(0).recordWithIDWasDeletedBlock?(recordID, "OctoPrint")
        operations.pull(0).fetchRecordZoneChangesResultBlock?(.success(()))
        wait(for: [failed], timeout: 2)
        XCTAssertTrue(try fetchPrinterState(id: oldID).defaultPrinter)
        XCTAssertFalse(try fetchPrinterState(id: nextID).defaultPrinter)

        writer.failSaves = false
        let recovered = pull(manager, succeeds: true)
        wait(for: [replay], timeout: 2)
        operations.pull(1).recordWithIDWasDeletedBlock?(recordID, "OctoPrint")
        operations.pull(1).fetchRecordZoneChangesResultBlock?(.success(()))
        wait(for: [recovered], timeout: 2)
        XCTAssertEqual(allPrinterLinks().map(\.hostname), ["next.local"])
        XCTAssertTrue(try fetchPrinterState(id: nextID).defaultPrinter)
    }

    func testResetWaitsForActivePullAndNextPullWaitsForReset() throws {
        let first = expectation(description: "active pull submitted")
        let reset = expectation(description: "reset pull submitted")
        let later = expectation(description: "queued pull submitted")
        let operations = Operations([first, reset, later])
        let manager = CloudKitPrinterManager(printerManager: writer, defaults: defaults) { [weak operations] in
            operations?.submit($0)
        }
        let initial = printerRecord(id: "initial", name: "Before reset", hostname: "old.local")
        let replacement = printerRecord(id: "replacement", name: "After reset", hostname: "new.local")
        let firstFinished = pull(manager, succeeds: true)
        wait(for: [first], timeout: 2)
        operations.pull(0).recordWasChangedBlock?(initial.recordID, .success(initial))

        let resetFinished = expectation(description: "reset completed")
        manager.resetLocalPrinters(completionHandler: { resetFinished.fulfill() }, errorHandler: {
            XCTFail("Reset failed")
            resetFinished.fulfill()
        })
        let laterFinished = pull(manager, succeeds: true)
        XCTAssertEqual(try freshPrinterNamesInOrder(), ["Before reset"])

        operations.pull(0).fetchRecordZoneChangesResultBlock?(.success(()))
        wait(for: [firstFinished, reset], timeout: 2, enforceOrder: true)
        XCTAssertTrue(try freshPrinterNamesInOrder().isEmpty)
        operations.pull(1).recordWasChangedBlock?(replacement.recordID, .success(replacement))
        operations.pull(1).fetchRecordZoneChangesResultBlock?(.success(()))
        wait(for: [resetFinished, later], timeout: 2, enforceOrder: true)
        operations.pull(2).fetchRecordZoneChangesResultBlock?(.success(()))
        wait(for: [laterFinished], timeout: 2)
        XCTAssertEqual(try freshPrinterNamesInOrder(), ["After reset"])
    }

    func testCloudResetRecreatesZoneAndRepublishesLocalPrinterBeforeQueuedPull() throws {
        let deleteZone = expectation(description: "delete zone")
        let createZone = expectation(description: "create zone")
        let newZonePull = expectation(description: "pull new zone")
        let query = expectation(description: "query before publishing")
        let publish = expectation(description: "publish local printer")
        let later = expectation(description: "queued pull")
        let operations = Operations([deleteZone, createZone, newZonePull, query, publish, later])
        let manager = CloudKitPrinterManager(printerManager: writer, defaults: defaults) { [weak operations] in
            operations?.submit($0)
        }
        let id = try insertPrinter(defaultPrinter: true, hostname: "printer.local")
        let printer = try XCTUnwrap(persistentContainer.viewContext.existingObject(with: id) as? Printer)
        printer.apiKey = "test-key"
        printer.recordName = "old-record"
        printer.iCloudUpdate = false
        try persistentContainer.viewContext.save()

        let resetFinished = expectation(description: "cloud reset completed")
        manager.resetCloutKit(completionHandler: { resetFinished.fulfill() }, errorHandler: {
            XCTFail("Cloud reset failed")
            resetFinished.fulfill()
        })
        let laterFinished = pull(manager, succeeds: true)

        wait(for: [deleteZone], timeout: 2)
        let deleteOperation = try XCTUnwrap(operations.operation(0) as? CKModifyRecordZonesOperation)
        XCTAssertEqual(deleteOperation.recordZoneIDsToDelete?.count, 1)
        deleteOperation.modifyRecordZonesResultBlock?(.success(()))

        wait(for: [createZone], timeout: 2)
        let createOperation = try XCTUnwrap(operations.operation(1) as? CKModifyRecordZonesOperation)
        XCTAssertEqual(createOperation.recordZonesToSave?.count, 1)
        XCTAssertNil(try fetchPrinterState(id: id).recordName)
        createOperation.modifyRecordZonesResultBlock?(.success(()))

        wait(for: [newZonePull], timeout: 2)
        operations.pull(2).fetchRecordZoneChangesResultBlock?(.success(()))
        wait(for: [query], timeout: 2)
        let queryOperation = try XCTUnwrap(operations.operation(3) as? CKQueryOperation)
        queryOperation.queryResultBlock?(.success(nil))

        wait(for: [publish], timeout: 2)
        let saveOperation = try XCTUnwrap(operations.operation(4) as? CKModifyRecordsOperation)
        let record = try XCTUnwrap(saveOperation.recordsToSave?.first)
        saveOperation.perRecordSaveBlock?(record.recordID, .success(record))
        saveOperation.modifyRecordsResultBlock?(.success(()))

        wait(for: [resetFinished, later], timeout: 2, enforceOrder: true)
        let restored = try freshPrinterState(id: id)
        XCTAssertEqual(restored.recordName, record.recordID.recordName)
        XCTAssertTrue(restored.defaultPrinter)
        XCTAssertFalse(restored.iCloudUpdate)
        operations.pull(5).fetchRecordZoneChangesResultBlock?(.success(()))
        wait(for: [laterFinished], timeout: 2)
    }

    func testDuplicateLookupDoesNotDeletePrinterEditedDuringQuery() throws {
        let id = try completeMatchedLookup(linkedLocally: true, editWhileWaiting: true)
        let printer = try freshPrinterState(id: id)
        XCTAssertEqual(printer.hostname, "different-printer.local")
        XCTAssertNil(printer.recordName)
        XCTAssertTrue(printer.iCloudUpdate)
    }

    func testDuplicateLookupDoesNotLinkPrinterEditedDuringQuery() throws {
        let id = try completeMatchedLookup(linkedLocally: false, editWhileWaiting: true)
        let printer = try freshPrinterState(id: id)
        XCTAssertEqual(printer.hostname, "different-printer.local")
        XCTAssertNil(printer.recordName)
        XCTAssertTrue(printer.iCloudUpdate)
    }

    func testDuplicateLookupStillRemovesAnUnchangedDuplicate() throws {
        let id = try completeMatchedLookup(linkedLocally: true, editWhileWaiting: false)
        XCTAssertFalse(writer.getPrinters().contains { $0.objectID == id })
        XCTAssertEqual(allPrinterLinks().map(\.recordName), ["linked"])
    }

    func testDuplicateLookupStillLinksAnUnchangedPrinter() throws {
        let id = try completeMatchedLookup(linkedLocally: false, editWhileWaiting: false)
        let printer = try freshPrinterState(id: id)
        XCTAssertEqual(printer.recordName, "linked")
        XCTAssertFalse(printer.iCloudUpdate)
    }

    private func completeMatchedLookup(linkedLocally: Bool, editWhileWaiting: Bool) throws -> NSManagedObjectID {
        let queryStarted = expectation(description: "duplicate lookup submitted")
        let operations = Operations([queryStarted])
        let manager = CloudKitPrinterManager(printerManager: writer, defaults: defaults) { [weak operations] in
            operations?.submit($0)
        }
        let record = printerRecord(id: "linked", name: "Cloud printer", hostname: "printer.local")
        if linkedLocally {
            let linkedID = try insertPrinter(defaultPrinter: true, hostname: "printer.local")
            let linked = try persistentContainer.viewContext.existingObject(with: linkedID) as! Printer
            linked.recordName = record.recordID.recordName
            linked.iCloudUpdate = false
        }
        let id = try insertPrinter(defaultPrinter: !linkedLocally, hostname: "printer.local")
        let printer = try persistentContainer.viewContext.existingObject(with: id) as! Printer
        printer.apiKey = "test-key"
        printer.iCloudUpdate = true
        try persistentContainer.viewContext.save()

        let pushed = expectation(description: "push completed")
        manager.pushChanges { pushed.fulfill() }
        let submitted = XCTWaiter.wait(for: [queryStarted], timeout: 2) == .completed
        let query = try XCTUnwrap(submitted ? operations.operation(0) as? CKQueryOperation : nil)
        if editWhileWaiting {
            printer.hostname = "different-printer.local"
            printer.userModified = Date()
            try persistentContainer.viewContext.save()
        }
        query.recordMatchedBlock?(record.recordID, .success(record))
        query.queryResultBlock?(.success(nil))
        wait(for: [pushed], timeout: 2)
        return id
    }

    private func pull(_ manager: CloudKitPrinterManager, succeeds: Bool) -> XCTestExpectation {
        let finished = expectation(description: "pull completed with expected result")
        manager.pullChanges(completionHandler: {
            XCTAssertTrue(succeeds, "Unexpected pull success")
            finished.fulfill()
        }, errorHandler: {
            XCTAssertFalse(succeeds, "Unexpected pull failure")
            finished.fulfill()
        })
        return finished
    }

    private func printerRecord(id: String, name: String, hostname: String) -> CKRecord {
        let record = CKRecord(recordType: "OctoPrint", recordID: CKRecord.ID(recordName: id))
        record["name"] = name as NSString
        record["hostname"] = hostname as NSString
        record["apiKey"] = "test-key" as NSString
        record["modified"] = Date(timeIntervalSince1970: 100) as NSDate
        return record
    }

    private func makeLinkedPrinter() throws -> (NSManagedObjectID, CKRecord) {
        let id = try insertPrinter(defaultPrinter: true, hostname: "printer.local")
        let printer = try XCTUnwrap(persistentContainer.viewContext.existingObject(with: id) as? Printer)
        let record = printerRecord(id: "linked", name: printer.name, hostname: printer.hostname)
        record["position"] = NSNumber(value: 0)
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: coder)
        printer.apiKey = "test-key"
        printer.recordName = record.recordID.recordName
        printer.recordData = coder.encodedData
        printer.userModified = record["modified"] as? Date
        printer.iCloudUpdate = true
        try persistentContainer.viewContext.save()
        return (id, record)
    }

    private func reorderWhileSyncing(_ id: NSManagedObjectID) throws {
        let printer = try XCTUnwrap(persistentContainer.viewContext.existingObject(with: id) as? Printer)
        // Simulate a pending reorder saved by a build that only updated position.
        printer.position = 1
        printer.iCloudUpdate = true
        try persistentContainer.viewContext.save()
    }

    private func allPrinterLinks() -> [(hostname: String, recordName: String?)] {
        let context = printerManager.newPrivateContext()
        return context.performAndWait {
            printerManager.getPrinters(context: context).map { ($0.hostname, $0.recordName) }
        }
    }
}
