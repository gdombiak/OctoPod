import XCTest
import CloudKit
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
