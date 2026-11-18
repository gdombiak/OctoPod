import Foundation
import CloudKit
import CoreData
import UIKit

class CloudKitPrinterManager {
    
    private let SYNC_STOPPED = "CK_SYNC_STOPPED"  // Key to track if CloudKit sync is enabled or not in the app. Controlled by user from the app. Do not confuse with 'is user logged into iCloud'
    private var accountAvailable = true
    
    let SUBSCRIPTION_ID = "SUBSCRIPTION_ID"  // ID of one time subcription to receive push notifications
    private let SUBSCRIPTION_CREATED = "CK_SUBSCRIPTION_CREATED"  // Key to track creation of one time subcription to receive push notifications
    private let CHANGE_TOKEN = "CK_CHANGE_TOKEN" // Key to use for storing token that tracks last processed changes from CloudKit server
    
    private let RECORD_TYPE = "OctoPrint"
    private let zoneID = CKRecordZone.ID(zoneName: "MyOctoPod", ownerName: CKCurrentUserDefaultName)
    
    private let printerManager: PrinterManager!
    private let synchronizationLock = NSLock()
    private let syncQueue = DispatchQueue(label: "org.OctoPod.CloudKitPrinterSync", qos: .utility)
    private var syncInProgress = false
    private var pendingSyncJobs: [(@escaping () -> Void) -> Void] = []
    private let defaults: UserDefaults
    private let submitOperation: (CKDatabaseOperation) -> Void
    private var starting = false
    private var startupRequested = false
    private let recoverPurgedStore: Bool
    private var listeningToCloudKitEvents = false

    private var iCloudAvailable: Bool {
        get {
            synchronizationLock.lock()
            defer { synchronizationLock.unlock() }
            return accountAvailable
        }
        set {
            synchronizationLock.lock()
            defer { synchronizationLock.unlock() }
            accountAvailable = newValue
        }
    }
    
    var delegates: Array<CloudKitPrinterDelegate> = Array()
    var logDelegates: Array<CloudKitPrinterLogDelegate> = Array()
    
    // Keep a log of events that happend. Log will only keep a certain number of entries to preserve memory
    private(set) var log: Array<CloudKitPrinterLogEntry> = Array()
    private let LOG_MAX_SIZE = 30
    
    init(printerManager: PrinterManager, recoverPurgedStore: Bool = false, defaults: UserDefaults = .standard,
         submitOperation: @escaping (CKDatabaseOperation) -> Void = {
             CKContainer(identifier: "iCloud.org.OctoPod.OctoPod").privateCloudDatabase.add($0)
         }) {
        self.recoverPurgedStore = recoverPurgedStore
        self.printerManager = printerManager
        self.defaults = defaults
        self.submitOperation = submitOperation
        
        // Listen when app went to background so we stop listening to CloudKit events
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    // MARK: - Start
    
    // Start synchronizing with iCloud (if available)
    func start(_ onceStarted: (() -> Void)?) {
        if !beginStarting() {
            // Do nothing since we are already starting
            return
        }

        if recoverPurgedStore { listenToCloudKitEvents() }
        discoverAccountStatus {
            if self.iCloudAvailable {
                // Wait 500ms before pushing local changes (of printers) to CloudKit (to sync other devices)
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5) {
                    // Listen to CK change events only if iCloud is available
                    self.listenToCloudKitEvents()

                    // Make sure that we have a subscription to CloudKit changes (so we can listen
                    // when other devices of the same user, that is logged in iCloud, change their printers information)
                    self.checkNotificationsSubscription()
                    
                    self.syncPrintersAtStartup(onceStarted: onceStarted)
                }
            } else {
                self.finishStarting()
                onceStarted?()
            }
        }
    }

    private func syncPrintersAtStartup(allowEmptyStoreRetry: Bool = true, onceStarted: (() -> Void)?) {
        let handleFailure = {
            if self.recoverPurgedStore, allowEmptyStoreRetry, !self.cloudKitSyncStopped(), self.localPrinterStoreIsEmpty() {
                // Keep this attempt active so a foreground or account event cannot overlap the retry.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    guard UIApplication.shared.applicationState != .background,
                          !self.cloudKitSyncStopped(), self.localPrinterStoreIsEmpty() else {
                        self.finishStarting()
                        onceStarted?()
                        return
                    }
                    DispatchQueue.global(qos: .utility).async {
                        self.syncPrintersAtStartup(allowEmptyStoreRetry: false, onceStarted: onceStarted)
                    }
                }
                return
            }
            self.finishStarting()
            onceStarted?()
        }

        enqueueSync { done in
            self.checkZone { error in
                if let error {
                    self.appendLog("Error making sure app has its own CKRecordZone. \(error)")
                    handleFailure()
                    done()
                    return
                }
                self.performPull { error in
                    if error != nil {
                        handleFailure()
                        done()
                    } else {
                        self.performPush {
                            self.finishStarting()
                            onceStarted?()
                            done()
                        }
                    }
                }
            }
        }
    }

    private func localPrinterStoreIsEmpty() -> Bool {
        let context = printerManager.newPrivateContext()
        return context.performAndWait {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Printer")
            return (try? context.count(for: request)) == 0
        }
    }

    @objc private func accountChanged(_ notification: Notification) {
        start(nil)
    }
    
    @objc func appDidEnterBackground() {
        synchronizationLock.lock()
        defer { synchronizationLock.unlock() }
        NotificationCenter.default.removeObserver(self, name: Notification.Name.CKAccountChanged, object: nil)
        listeningToCloudKitEvents = false
        startupRequested = false
    }
    
    
    // MARK: - Delegates operations
    
    func remove(cloudKitPrinterDelegate toRemove: CloudKitPrinterDelegate) {
        delegates.removeAll(where: { $0 === toRemove })
    }
    
    func remove(cloudKitPrinterLogDelegate toRemove: CloudKitPrinterLogDelegate) {
        logDelegates.removeAll(where: { $0 === toRemove })
    }
    
    // MARK: Enable sync operations
    
    // As a safety measure, because all this code is too complex, we want to let users
    // disable this feature and use OctoPod with no device synchronization via iCloud
    func stopCloudKitSync(stop: Bool) {
        defaults.set(stop, forKey: SYNC_STOPPED)
    }
    
    // Returns true if user does not allow device synchronizion (via iCloud)
    // User can allow device synchronization but they need to be logged into
    // iCloud for this to work
    func cloudKitSyncStopped() -> Bool {
        return defaults.bool(forKey: SYNC_STOPPED)
    }
    
    // MARK: Subscription operations
    
    // Create a one time subscription to get silent push notifications when other devices make changes to CloudKit records
    // AppDelegate is configured to request to "listen to remote notifications" and call into #handleNotifications()
    fileprivate func checkNotificationsSubscription() {
        let created = defaults.bool(forKey: SUBSCRIPTION_CREATED)
        if !created {
            let predicate = NSPredicate(value: true)
            let subscription = CKQuerySubscription(recordType: RECORD_TYPE,
                                                   predicate: predicate,
                                                   subscriptionID: SUBSCRIPTION_ID,
                                                   options: [CKQuerySubscription.Options.firesOnRecordCreation, CKQuerySubscription.Options.firesOnRecordDeletion, CKQuerySubscription.Options.firesOnRecordUpdate])
            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true // Use silent content notifications - user will not be prompt for permissions
            subscription.notificationInfo = notificationInfo
            
            let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: [])
            setModifySubscriptionsCompletion(operation) { (saved: [CKSubscription]?, deletedIDs: [CKSubscription.ID]?, error: Error?) -> Void in
                if let error = error {
                    self.appendLog("Error saving subcription: \(error)")
                    return
                }
                // Record that (one time) subscription has been created
                self.defaults.set(true, forKey: self.SUBSCRIPTION_CREATED)
            }
            operation.qualityOfService = .utility
            
            submitOperation(operation)
        }
    }
    
    // MARK: - Zone operations
    
    fileprivate func checkZone(completion: @escaping (Error?) -> Void) {
        // Check that we have our custom zone
        let operation = CKFetchRecordZonesOperation(recordZoneIDs: [zoneID])
        setFetchRecordZonesCompletion(operation) { recordZonesByZoneID, error in
            if let error = error {
                if let ckerror = error as? CKError {
                    if ckerror.isZoneNotFound() || ckerror.isUserDeletedZone() {
                        self.recoverMissingZone(completion: completion)
                    } else {
                        // Zone not available for some reason
                        completion(error)
                    }
                } else {
                    // Zone not available for some reason
                    completion(error)
                }
            } else {
                // Zone exists
                completion(nil)
            }
        }
        operation.qualityOfService = .utility
        submitOperation(operation)
    }
    
    // Create a custom zone where we store our records. We need to use a custom zone
    // and not the default one since we are doing incremental reads which is not supported
    // in default zone
    fileprivate func createZone(completion: @escaping (Error?) -> Void) {
        let recordZone = CKRecordZone(zoneID: zoneID)
        let operation = CKModifyRecordZonesOperation(recordZonesToSave: [recordZone], recordZoneIDsToDelete: [])
        setModifyRecordZonesCompletion(operation) { savedRecordZones, deletedRecordZoneIDs, error in
            guard error == nil else {
                completion(error)
                return
            }
            self.appendLog("Zone created")
            completion(nil)
        }
        operation.qualityOfService = .utility
        submitOperation(operation)
    }
    
    fileprivate func deleteZone(completion: @escaping (Error?) -> Void) {
        let operation = CKModifyRecordZonesOperation(recordZonesToSave: [], recordZoneIDsToDelete: [zoneID])
        setModifyRecordZonesCompletion(operation) { savedRecordZones, deletedRecordZoneIDs, error in
            guard error == nil else {
                completion(error)
                return
            }
            self.appendLog("Zone deleted")
            completion(nil)
        }
        operation.qualityOfService = .utility
        submitOperation(operation)
    }
    
    // MARK: - Pull from iCloud

    func pullChanges(completionHandler: (() -> Void)?, errorHandler: (() -> Void)?) {
        enqueueSync { done in
            self.performPull { error in
                if error == nil {
                    completionHandler?()
                } else {
                    errorHandler?()
                }
                done()
            }
        }
    }

    private func performPull(allowRecovery: Bool = true, localPrintersChanged: Bool = false,
                             completion: @escaping (Error?) -> Void) {
        func finish(_ error: Error?, printersChanged: Bool) {
            if let error {
                appendLog("Error fetching zone changes: \(error)")
            }
            if printersChanged { notifyPrintersUpdated() }
            completion(error)
        }

        guard !cloudKitSyncStopped(), iCloudAvailable else {
            finish(nil, printersChanged: localPrintersChanged)
            return
        }

        let context = printerManager.newPrivateContext(writer: "CloudKit.pull")
        context.performAndWait { context.mergePolicy = NSErrorMergePolicy }
        var progress = CloudKitPrinterPullProgress()
        progress.printersChanged = localPrintersChanged
        let options = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        if let data = defaults.data(forKey: CHANGE_TOKEN) {
            if recoverPurgedStore && localPrinterStoreIsEmpty() {
                // The cache may be gone while its change token survives.
                defaults.removeObject(forKey: CHANGE_TOKEN)
            } else {
                do {
                    options.previousServerChangeToken = try NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
                } catch {
                    appendLog("Error unarchiving change token: \(error)")
                }
            }
        }

        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zoneID], configurationsByRecordZoneID: [zoneID: options])
        operation.fetchAllChanges = true

        // CloudKit runs the callbacks for this operation serially. Each local save finishes
        // before the next callback. The next sync job waits for the terminal completion.
        func apply(_ change: () throws -> Bool) {
            guard progress.localError == nil else { return }
            // Fetch the latest committed fields on every record. Treat any concurrent
            // writer during this save as a failure so the record can be replayed.
            defer { context.performAndWait { context.reset() } }
            do {
                if try change() { progress.printersChanged = true }
            } catch {
                progress.localError = error
            }
        }

        func stageCheckpoint(_ token: CKServerChangeToken?) {
            guard progress.localError == nil, let token else { return }
            do {
                progress.checkpoint = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: false)
            } catch {
                progress.localError = error
            }
        }

        setRecordWasChanged(operation) { record in
            apply { try self.recordChanged(record, in: context) }
        }
        operation.recordWithIDWasDeletedBlock = { recordID, _ in
            apply { try self.recordDeleted(recordID, in: context) }
        }
        setRecordZoneChangeTokensUpdated(operation) { _, token, _ in
            stageCheckpoint(token)
        }
        setRecordZoneFetchCompletion(operation) { _, token, _, _, error in
            if let error {
                progress.zoneError = error
            } else {
                stageCheckpoint(token)
            }
        }
        setFetchRecordZoneChangesCompletion(operation) { operationError in
            let error = progress.finish(operationError: operationError) { data in
                self.defaults.set(data, forKey: self.CHANGE_TOKEN)
            }
            if allowRecovery, progress.localError == nil, let cloudError = error as? CKError {
                if cloudError.isZoneNotFound() || cloudError.isUserDeletedZone() {
                    self.recoverMissingZone { error in
                        if let error {
                            finish(error, printersChanged: progress.printersChanged)
                        } else {
                            self.performPull(allowRecovery: false, localPrintersChanged: progress.printersChanged, completion: completion)
                        }
                    }
                    return
                }
                if cloudError.isChangeTokenExpired() {
                    do {
                        try self.resetCloudKitLinks()
                        self.performPull(allowRecovery: false, localPrintersChanged: progress.printersChanged, completion: completion)
                    } catch {
                        finish(error, printersChanged: progress.printersChanged)
                    }
                    return
                }
            }
            finish(error, printersChanged: progress.printersChanged)
        }
        operation.qualityOfService = .utility
        submitOperation(operation)
    }

    private func recoverMissingZone(completion: @escaping (Error?) -> Void) {
        do {
            // If the local save fails, the next attempt can still detect the missing zone.
            try resetCloudKitLinks()
        } catch {
            completion(error)
            return
        }
        createZone(completion: completion)
    }

    private func resetCloudKitLinks() throws {
        try printerManager.resetPrintersForiCloud(context: printerManager.newPrivateContext(writer: "CloudKit.resetLinks"))
        defaults.removeObject(forKey: CHANGE_TOKEN)
    }

    private func recordChanged(_ record: CKRecord, in context: NSManagedObjectContext) throws -> Bool {
        let recordName = record.recordID.recordName
        let parsed = parseRecord(record: record)
        guard PrinterConnectionType(rawValue: parsed.connectionType) != nil else {
            appendLog("Ignored record with an unknown connection type: \(recordName)")
            return false
        }

        let change: (NSManagedObjectID, Bool, String)? = try context.performAndWait {
            let printers = try printerManager.fetchPrinters(in: context)
            let linked = printers.first { $0.recordName == recordName }
            let unlinked = printers.filter { $0.recordName == nil && $0.hostname == parsed.hostname }
            // Match the ordinary single local printer by host. If there are multiple
            // unlinked entries for the host, only link a uniquely matching API key.
            let keyMatches = unlinked.filter { $0.apiKey == parsed.apiKey }
            let existing = linked ?? (unlinked.count == 1 ? unlinked.first : (keyMatches.count == 1 ? keyMatches.first : nil))
            let printer: Printer
            if let existing {
                printer = existing
            } else {
                guard let name = parsed.name, let hostname = parsed.hostname, let apiKey = parsed.apiKey else {
                    return nil
                }
                printer = printerManager.insertPrinter(in: context, isDefault: !printers.contains(where: \.defaultPrinter))
                printer.name = name
                printer.hostname = hostname
                printer.apiKey = apiKey
                printer.position = parsed.position ?? Int16(clamping: printers.count)
                printer.userModified = parsed.modified ?? Date()
            }

            let localDate = existing?.userModified ?? .distantPast
            let remoteDate = parsed.modified ?? .distantPast
            // Older versions changed the position without updating the modification date.
            let pendingReorder = localDate == remoteDate && parsed.position.map { $0 != printer.position } == true
            if let existing, existing.iCloudUpdate, localDate > remoteDate || pendingReorder {
                // Keep pending local fields and use the incoming record as the base for the next push.
                printer.recordName = recordName
                printer.recordData = encodeRecord(record: record)
            } else {
                updatePrinterFields(printer: printer, from: record)
            }

            let saved = existing == nil
                ? printerManager.saveObject(printer, context: context)
                : printerManager.updatePrinter(printer, context: context)
            guard saved else {
                context.rollback()
                throw CloudKitPrinterSyncError.saveFailed(recordName)
            }
            return (printer.objectID, existing == nil, printer.hostname)
        }

        guard let (id, added, hostname) = change else {
            appendLog("Ignored incomplete record: \(recordName)")
            return false
        }
        if added {
            notifyPrinterAdded(printerID: id)
            appendLog("Added new printer: \(hostname)")
        } else {
            notifyPrinterUpdated(printerID: id)
            appendLog("Updated printer: \(hostname)")
        }
        return true
    }

    private func recordDeleted(_ recordID: CKRecord.ID, in context: NSManagedObjectContext) throws -> Bool {
        let deleted: (NSManagedObjectID, String)? = try context.performAndWait {
            let request = NSFetchRequest<Printer>(entityName: "Printer")
            request.predicate = NSPredicate(format: "recordName = %@", recordID.recordName)
            request.fetchLimit = 1
            guard let printer = try context.fetch(request).first else { return nil }
            let snapshot = (printer.objectID, printer.hostname)
            guard printerManager.deletePrinter(printer, context: context) else {
                context.rollback()
                throw CloudKitPrinterSyncError.saveFailed(recordID.recordName)
            }
            return snapshot
        }
        guard let (id, hostname) = deleted else { return false }
        notifyPrinterDeleted(printerID: id)
        appendLog("Deleted printer: \(hostname)")
        return true
    }

    // MARK: - Push to iCloud
    
    // Printers with status iCloudUpdate will be pushed to iCloud
    //
    // Deleted printers are not included in here. When deleting a printer we try to
    // update iCloud and if that fails then iCloud will end up with a printer we do
    // not have and upon next pull a local printer will be recreated again
    //
    // Updates to iCloud from this app will not trigger push notifications to
    // this app so there is no need to protect from endless loops
    func pushChanges(completion: (() -> Void)?) {
        enqueueSync { done in
            self.performPush {
                completion?()
                done()
            }
        }
    }

    private func performPush(completion: @escaping () -> Void) {
        // If user disabled CloudKit sync then do nothing
        if cloudKitSyncStopped() || !iCloudAvailable {
            completion()
            return
        }
        let context = printerManager.newPrivateContext(writer: "CloudKit.push")
        context.perform {
            var toRemove: Array<PrinterData> = Array()
            for printer in self.printerManager.getPrinters(context: context) {
                if printer.iCloudUpdate {
                    var printerData = PrinterData(printerID: printer.objectID, name: printer.name, hostname: printer.hostname, apiKey: printer.apiKey, connectionType: printer.connectionType, position: printer.position)
                    printerData.username = printer.username
                    printerData.password = printer.password
                    printerData.headers = printer.headers
                    printerData.userModified = printer.userModified
                    printerData.recordData = printer.recordData
                    toRemove.append(printerData)
                }
            }
            self.pushChange(index: 0, toRemove: toRemove, completion: completion)
        }
    }
    
    // A printer has been deleted from Core Data and we now need to delete from iCloud
    // If this operation fails, there is no recovery since we are not implementing local deletes
    func pushDeletedPrinter(printer: Printer) {
        // If user disabled CloudKit sync then do nothing
        if cloudKitSyncStopped() || !iCloudAvailable {
            return
        }
        if let recordData = printer.recordData {
            if let record = decodeRecordData(recordData: recordData) {
                let hostname = printer.hostname
                deleteRecord(recordID: record.recordID) { error in
                    if let error {
                        self.appendLog("Failed to delete printer: \(hostname). Error: \(error)")
                    } else {
                        self.appendLog("Pushed delete for printer: \(hostname)")
                    }
                }
            }
        }
    }
    
    // Push one at a time to prevent concurrency issues with Core Data
    fileprivate func pushChange(index: Int, toRemove: Array<PrinterData>, completion: (() -> Void)?) {
        if index < toRemove.count {
            let printerData = toRemove[index]
            let hostname = printerData.hostname
            self.save(printerData: printerData, completion: { error in
                if let error = error {
                    self.appendLog("Failed to push changes for printer: \(hostname). Error: \(error)")
                } else {
                    self.appendLog("Pushed changes for printer: \(hostname)")
                }
                self.pushChange(index: (index + 1), toRemove: toRemove, completion: completion)
            })
        } else {
            completion?()
        }
    }
    
    // Save printer information to iCloud
    // If printer was never saved then we will check if a record in iCloud exists with the same information.
    // If not then we create one, otherwise we update printer with record information (ie. link things)
    // If printer was already saved to iCloud then we will update iCloud information with printer information
    fileprivate func save(printerData: PrinterData, completion: ((Error?) -> Void)?) {
        if let recordData = printerData.recordData {
            // Printer was once stored in iCloud. Decode encoded CloudKit record stored in the printer
            if let record = decodeRecordData(recordData: recordData) {
                // Update record with printer information. Record got last updated when stored
                // in iCloud, this is why we need to update it with new printer data
                self.updateRecordFields(record: record, from: printerData)
                // Save record to iCloud (and do any merge if needed)
                saveAndMerge(record: record) { serverRecord, originalUpdated, error in
                    if let error = error {
                        // Failed to save to iCloud
                        completion?(error)
                    } else if let newRecord = serverRecord {
                        // Record has been saved
                        let saveError = self.updateAndSave(printerData: printerData, serverRecord: newRecord)
                        
                        if saveError == nil, originalUpdated {
                            // Record has been updated with iCloud information
                            // During the save we found another version on the server side and
                            // the merging logic determined we should update our local data to match
                            // what was in the iCloud database.
                            self.notifyPrinterUpdated(printerID: printerData.printerID)
                        }
                        completion?(saveError)
                    } else {
                        completion?(CloudKitPrinterSyncError.missingCloudKitResult)
                    }
                }
            } else {
                completion?(CloudKitPrinterSyncError.invalidRecordData)
            }
        } else {
            // We don’t already have a record. See if there’s one up on iCloud
            self.queryRecord(hostname: printerData.hostname, apiKey: printerData.apiKey) { (records: [CKRecord]?, error: Error?) in
                if let error = error {
                    // There was an error querying iCloud
                    completion?(error)
                } else if let records = records {
                    if records.isEmpty {
                        // iCloud has no similar info so let's add this printer to iCloud
                        
                        // No record up on iCloud, so we’ll start with a
                        // brand new record.
                        let recordID = CKRecord.ID(recordName: UUID().uuidString , zoneID: self.zoneID)
                        let record = CKRecord(recordType: self.RECORD_TYPE, recordID: recordID)
                        self.updateRecordFields(record: record, from: printerData)
                        // Save new record
                        self.saveRecord(record: record, completion: { (record: CKRecord?, error: Error?) in
                            if let error = error {
                                completion?(error)
                            } else if let newRecord = record {
                                // Record has been saved
                                completion?(self.updateAndSave(printerData: printerData, serverRecord: newRecord))
                            } else {
                                completion?(CloudKitPrinterSyncError.missingCloudKitResult)
                            }
                        })
                    } else {
                        // Apply the query result only to the version of the printer we looked up.
                        let context = self.printerManager.newPrivateContext(writer: "CloudKit.link")
                        do {
                            let removedDuplicate = try context.performAndWait {
                                context.mergePolicy = NSErrorMergePolicy
                                let printers = try self.printerManager.fetchPrinters(in: context)
                                guard let printer = printers.first(where: { $0.objectID == printerData.printerID }),
                                      printer.iCloudUpdate,
                                      printer.recordData == printerData.recordData,
                                      !printerData.differsFromLocalFields(of: printer) else {
                                    throw CloudKitPrinterSyncError.stalePrinterSnapshot
                                }
                                let recordNames = Set(records.map { $0.recordID.recordName })
                                if printers.contains(where: { $0.objectID != printer.objectID && $0.recordName.map(recordNames.contains) == true }) {
                                    guard self.printerManager.deletePrinter(printer, context: context) else {
                                        throw CloudKitPrinterSyncError.saveFailed("duplicate printer")
                                    }
                                    return true
                                }
                                self.updatePrinterFields(printer: printer, from: records[0])
                                guard self.printerManager.updatePrinter(printer, context: context) else {
                                    throw CloudKitPrinterSyncError.saveFailed(records[0].recordID.recordName)
                                }
                                return false
                            }
                            if removedDuplicate {
                                self.notifyPrinterDeleted(printerID: printerData.printerID)
                            } else {
                                self.notifyPrinterUpdated(printerID: printerData.printerID)
                            }
                            completion?(nil)
                        } catch {
                            completion?(error)
                        }
                    }
                } else {
                    completion?(CloudKitPrinterSyncError.missingCloudKitResult)
                }
            }
        }
    }
    
    // This internal saveRecord method will repeatedly be called if needed in the case
    // of a merge. In those cases, we don’t have to repeat the CKRecord setup.
    fileprivate func saveAndMerge(record: CKRecord, completion: @escaping (CKRecord?, Bool, Error?) -> Void) {
        self.saveRecord(record: record) { savedRecord, error in
            if let error = error {
                if let ckerror = error as? CKError {
                    let (clientRec, serverRec) = ckerror.getMergeRecords()
                    guard let clientRecord = clientRec, let serverRecord = serverRec else {
                        // Failed but not due to a merge error
                        completion(nil, false, error)
                        return
                    }
                    
                    // This is the merge case. Check the modified dates and choose
                    // the most-recently modified one as the winner. This is just a very
                    // basic example of conflict handling, more sophisticated data models
                    // will likely require more nuance here.
                    let clientModified = clientRecord["modified"] as? Date
                    let serverModified = serverRecord["modified"] as? Date
                    if let clientModified, clientModified > (serverModified ?? .distantPast) {
                        // We’ve decided ours is the winner, so do the update again
                        // using the current iCloud ServerRecord as the base CKRecord.
                        self.updateRecord(source: clientRecord, target: serverRecord)
                        serverRecord["modified"] = clientModified as NSDate
                        self.saveAndMerge(record: serverRecord) { savedRecord, modified, error in
                            completion(savedRecord, modified, error)
                        }
                    }
                    else {
                        // We’ve decided the iCloud version is the winner.
                        // No need to overwrite it there but we’ll update our
                        // local information to match to stay in sync.
                        completion(serverRecord, true, nil)
                    }
                } else {
                    // Failed with some unknown Error
                    completion(nil, false, error)
                }
            } else {
                completion(savedRecord, false, nil)
            }
        }
    }
    
    // MARK: - CloudKit Record operations
    
    // Fetch a record from the iCloud database
    fileprivate func loadRecord(name: String, completion: @escaping (CKRecord?, Error?) -> Void) {
        let recordID = CKRecord.ID(recordName: name, zoneID: self.zoneID)
        let operation = CKFetchRecordsOperation(recordIDs: [recordID])
        setFetchRecordsCompletion(operation) { records, error in
            guard error == nil else {
                completion(nil, error)
                return
            }
            guard let noteRecord = records?[recordID] else {
                // Didn't get the record we asked about?
                // This shouldn’t happen but we’ll be defensive.
                completion(nil, CKError.unknownItem as? Error)
                return
            }
            completion(noteRecord, nil)
        }
        operation.qualityOfService = .utility
        
        submitOperation(operation)
    }
    
    // Query records from the iCloud database that match the specified criteria
    fileprivate func queryRecord(hostname: String, apiKey: String, completion: @escaping ([CKRecord]?, Error?) -> Void) {
        let predicate = NSPredicate(format: "hostname = %@ && apiKey = %@", hostname, apiKey)
        let query = CKQuery(recordType: RECORD_TYPE, predicate: predicate)
        var records: [CKRecord] = []
        func fetchPage(_ operation: CKQueryOperation) {
            setRecordMatched(operation) { records.append($0) }
            setQueryCompletion(operation) { cursor, error in
                if let error {
                    completion(nil, error)
                } else if let cursor {
                    fetchPage(CKQueryOperation(cursor: cursor))
                } else {
                    completion(records, nil)
                }
            }
            operation.qualityOfService = .utility
            submitOperation(operation)
        }
        fetchPage(CKQueryOperation(query: query))
    }
    
    // Save a record to the iCloud database
    // Create zone if needed. Any other error is not handled and passed to completion block
    fileprivate func saveRecord(record: CKRecord, allowZoneCreation: Bool = true, completion: @escaping (CKRecord?, Error?) -> Void) {
        let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: [])
        setModifyRecordsCompletion(operation) { (savedRecords: [CKRecord]?, deletedRecordIDs: [CKRecord.ID]?, error: Error?) in
            if let error = error {
                if let ckerror = error as? CKError {
                    if allowZoneCreation && ckerror.isZoneNotFound() {
                        // ZoneNotFound is the one error we can reasonably expect & handle here, since
                        // the zone isn't created automatically for us until we've saved one record.
                        // create the zone and, if successful, try again
                        self.createZone() { error in
                            if let error = error {
                                // Failed to create zone for some reason
                                completion(nil, error)
                            } else {
                                // Zone created so save record now
                                self.saveRecord(record: record, allowZoneCreation: false, completion: completion)
                            }
                        }
                    } else {
                        // Failed with some unknown CKError
                        completion(nil, error)
                    }
                } else {
                    // Failed with some unknown Error
                    completion(nil, error)
                }
            } else {
                // Success. Record saved
                if savedRecords != nil && !savedRecords!.isEmpty {
                    completion(savedRecords![0], nil)
                } else {
                    // Should not happen since we were able to save to iCloud
                    NSLog("CloudKit returned no record when it was able to save the record!")
                    completion(nil, nil)
                }
            }
        }
        operation.qualityOfService = .utility
        
        submitOperation(operation)
    }
    
    fileprivate func deleteRecord(recordID: CKRecord.ID, completion: @escaping (Error?) -> Void) {
        let operation = CKModifyRecordsOperation(recordsToSave: [], recordIDsToDelete: [recordID])
        setModifyRecordsCompletion(operation) { (savedRecords: [CKRecord]?, deletedRecordIDs: [CKRecord.ID]?, error: Error?) in
            if let error = error {
                if let ckerror = error as? CKError {
                    if !ckerror.isZoneNotFound() {
                        completion(error)
                    }
                } else {
                    // Failed with some unknown Error
                    completion(error)
                }
            } else {
                // Success. Record saved
                if deletedRecordIDs != nil && !deletedRecordIDs!.isEmpty {
                    completion(nil)
                } else {
                    // Should not happen (no errors and nothing deleted?)
                    NSLog("CloudKit returned no deleted record ids when it was able to delete the record!")
                    completion(nil)
                }
            }
        }
        operation.qualityOfService = .utility
        
        submitOperation(operation)
    }
    
    // MARK: - Reset operations
    
    // Delete CloudKit records and recreate from local stored data
    func resetCloutKit(completionHandler: (() -> Void)?, errorHandler: (() -> Void)?) {
        enqueueSync { done in
            func fail(_ error: Error) {
                self.appendLog("Error resetting CloudKit: \(error)")
                errorHandler?()
                done()
            }

            guard !self.cloudKitSyncStopped(), self.iCloudAvailable else {
                fail(CloudKitPrinterSyncError.syncUnavailable)
                return
            }
            self.deleteZone { error in
                if let error {
                    fail(error)
                    return
                }
                self.recoverMissingZone { error in
                    if let error {
                        fail(error)
                        return
                    }
                    self.performPull { error in
                        if let error {
                            fail(error)
                        } else {
                            self.performPush {
                                completionHandler?()
                                done()
                            }
                        }
                    }
                }
            }
        }
    }

    /// Delete local stored data and recreate from CloudKit records
    func resetLocalPrinters(completionHandler: (() -> Void)?, errorHandler: (() -> Void)?) {
        enqueueSync { done in
            guard !self.cloudKitSyncStopped(), self.iCloudAvailable else {
                self.appendLog("Cannot reset local printers while iCloud sync is unavailable")
                errorHandler?()
                done()
                return
            }
            // Invalidate before deleting. An interruption between the two must leave
            // a full pull pending, never an empty store with a valid incremental token.
            self.defaults.removeObject(forKey: self.CHANGE_TOKEN)
            let deleted: Bool
            do {
                deleted = try self.printerManager.deleteAllPrinters(context: self.printerManager.newPrivateContext(writer: "CloudKit.resetLocal"))
            } catch {
                self.appendLog("Error deleting local printers during reset: \(error)")
                errorHandler?()
                done()
                return
            }
            self.performPull(localPrintersChanged: deleted) { error in
                if error == nil {
                    completionHandler?()
                } else {
                    errorHandler?()
                }
                done()
            }
        }
    }

    // A job owns the CloudKit printer store through its asynchronous completion.
    // Enqueue and hand off on one queue without blocking it on a network request.
    private func enqueueSync(_ work: @escaping (@escaping () -> Void) -> Void) {
        syncQueue.async {
            self.pendingSyncJobs.append(work)
            self.startNextSync()
        }
    }

    private func startNextSync() {
        guard !syncInProgress, !pendingSyncJobs.isEmpty else { return }
        syncInProgress = true
        let work = pendingSyncJobs.removeFirst()
        work {
            self.syncQueue.async {
                self.syncInProgress = false
                self.startNextSync()
            }
        }
    }
    
    // MARK: - Delegate notifications operations
    
    fileprivate func notifyPrintersUpdated() {
        // Alert delegates that printers have been updated
        for delegate in self.delegates {
            delegate.printersUpdated()
        }
    }
    
    fileprivate func notifyPrinterAdded(printerID: NSManagedObjectID) {
        for delegate in self.delegates {
            delegate.printerAdded(printerID: printerID)
        }
    }
    
    fileprivate func notifyPrinterUpdated(printerID: NSManagedObjectID) {
        for delegate in self.delegates {
            delegate.printerUpdated(printerID: printerID)
        }
    }
    
    fileprivate func notifyPrinterDeleted(printerID: NSManagedObjectID) {
        for delegate in self.delegates {
            delegate.printerDeleted(printerID: printerID)
        }
    }
    
    fileprivate func notifyiCloudStatusChanged(connected: Bool) {
        for delegate in self.delegates {
            delegate.iCloudStatusChanged(connected: connected)
        }
    }
    
    // MARK: - iCloud Account Status operations
    
    fileprivate func discoverAccountStatus(attemptLeft: Int = 3, completion: (() -> Void)?) {
        getiCloudContainer().accountStatus { status, error in
            if let error = error {
                // some error occurred (probably a failed connection, try again)
                if attemptLeft > 0 {
                    self.discoverAccountStatus(attemptLeft: attemptLeft - 1, completion: completion)
                } else {
                    // Disable iCloud due to unkonwn error
                    self.appendLog("Disabling iCloud sync due to error: \(error)")
                    self.iCloudAvailable = false
                    self.notifyiCloudStatusChanged(connected: false)
                    completion?()
                }
            } else {
                switch status {
                case .available:
                    // the user is logged in
                    self.iCloudAvailable = true
                    self.notifyiCloudStatusChanged(connected: true)
                    completion?()
                case .noAccount:
                    // the user is NOT logged in
                    self.iCloudAvailable = false
                    self.notifyiCloudStatusChanged(connected: false)
                    completion?()
                case .couldNotDetermine:
                    // for some reason, the status could not be determined (try again)
                    if attemptLeft > 0 {
                        self.discoverAccountStatus(attemptLeft: attemptLeft - 1, completion: completion)
                    } else {
                        // Disable iCloud due to unkonwn error
                        self.appendLog("Disabling iCloud sync. Account status is: 'couldNotDetermine'")
                        self.iCloudAvailable = false
                        self.notifyiCloudStatusChanged(connected: false)
                        completion?()
                    }
                case .restricted:
                    // iCloud settings are restricted by parental controls or a configuration profile
                    self.iCloudAvailable = false
                    self.notifyiCloudStatusChanged(connected: false)
                    completion?()
                case .temporarilyUnavailable:
                    // iCloud is temporarily unavailable
                    self.iCloudAvailable = false
                    self.notifyiCloudStatusChanged(connected: false)
                    completion?()
                @unknown default:
                    // exception handling
                    self.iCloudAvailable = false
                    self.notifyiCloudStatusChanged(connected: false)
                    completion?()
                }
            }
        }
    }
    
    // MARK: - Log operations
    
    fileprivate func appendLog(_ description: String) {
        // Create new entry
        let entry = CloudKitPrinterLogEntry(date: Date(), description: description)
        
        // Make sure we do not exceed max log size
        if log.count > LOG_MAX_SIZE {
            // Remove first (oldest) entry
            log.remove(at: 0)
        }
        log.append(entry)
        
        // Alert delegates that log has been updated with a new entry
        for delegate in logDelegates {
            delegate.logUpdated(newEntry: entry)
        }
        
        // Also print to console
        NSLog(description)
    }
    
    // MARK: - Private operations
    
    fileprivate func getiCloudContainer() -> CKContainer {
        return CKContainer(identifier: "iCloud.org.OctoPod.OctoPod")
    }
    
    fileprivate func updatePrinterFields(printer: Printer, from record: CKRecord) {
        let parsed = parseRecord(record: record)
        if let name = parsed.name {
            printer.name = name
        }
        if let hostname = parsed.hostname {
            printer.hostname = hostname
        }
        if let apiKey = parsed.apiKey {
            printer.apiKey = apiKey
        }
        if let date = parsed.modified {
            printer.userModified = date
        }
        printer.connectionType = parsed.connectionType
        printer.username = parsed.username
        printer.password = parsed.password
        printer.headers = parsed.headers
        // Updated from iCloud so reset this flag since there is no need to push this data to iCloud (until modified)
        printer.iCloudUpdate = false
        // Assign PK to associate with record
        printer.recordName = record.recordID.recordName
        // Encode record and store it in printer
        printer.recordData = encodeRecord(record: record)
        if let parsedPosition = parsed.position {
            printer.position = parsedPosition
        }
    }
    
    fileprivate func updateRecordFields(record: CKRecord, from printerData: PrinterData) {
        record["name"] = printerData.name as NSString
        record["hostname"] = printerData.hostname as NSString
        record["apiKey"] = printerData.apiKey as NSString
        record["username"] = printerData.username as NSString?
        record["password"] = printerData.password as NSString?
        record["headers"] = printerData.headers as NSString?
        if let date = printerData.userModified {
            record["modified"] = date as NSDate
        }
        record["connectionType"] = NSNumber(value: printerData.connectionType)
        record["position"] = NSNumber(value: printerData.position)
    }
    
    private func updateAndSave(printerData: PrinterData, serverRecord: CKRecord) -> Error? {
        let context = printerManager.newPrivateContext(writer: "CloudKit.savePush")
        return context.performAndWait {
            context.mergePolicy = NSErrorMergePolicy
            do {
                guard let printer = try context.existingObject(with: printerData.printerID) as? Printer else {
                    return CloudKitPrinterSyncError.saveFailed(serverRecord.recordID.recordName)
                }
                if printer.iCloudUpdate, printerData.differsFromLocalFields(of: printer) {
                    printer.recordName = serverRecord.recordID.recordName
                    printer.recordData = encodeRecord(record: serverRecord)
                } else {
                    updatePrinterFields(printer: printer, from: serverRecord)
                }
                guard printerManager.updatePrinter(printer, context: context) else {
                    return CloudKitPrinterSyncError.saveFailed(serverRecord.recordID.recordName)
                }
                return nil
            } catch {
                return error
            }
        }
    }
    
    fileprivate func parseRecord(record: CKRecord) -> (name: String?, hostname: String?, apiKey: String?, username: String?, password: String?, headers: String?, modified: Date?, connectionType: Int16, position: Int16?) {
        let name = record["name"] as? String
        let hostname = record["hostname"] as? String
        let apiKey = record["apiKey"] as? String
        let username = record["username"] as? String
        let password = record["password"] as? String
        let headers = record["headers"] as? String
        let modified = record["modified"] as? Date
        let connectionTypeOptional = record["connectionType"] as? NSNumber
        let connectionType: Int16! = (connectionTypeOptional != nil) ? connectionTypeOptional!.int16Value : PrinterConnectionType.apiKey.rawValue
        let position = record["position"] as? Int16
        return (name, hostname, apiKey, username, password, headers, modified, connectionType, position)
    }
    
    fileprivate func updateRecord(source: CKRecord, target: CKRecord) {
        target["name"] = source["name"]
        target["hostname"] = source["hostname"]
        target["apiKey"] = source["apiKey"]
        target["username"] = source["username"]
        target["password"] = source["password"]
        target["headers"] = source["headers"]
        target["position"] = source["position"]
    }
    
    fileprivate func encodeRecord(record: CKRecord) -> Data {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: coder)
        return coder.encodedData
    }
    
    fileprivate func decodeRecordData(recordData: Data) -> CKRecord? {
        // set up the CKRecord with its metadata
        do {
            let coder = try NSKeyedUnarchiver(forReadingFrom: recordData)
            let record = CKRecord(coder: coder)
            coder.finishDecoding()
            return record
        } catch {
            self.appendLog("Error decodeRecordData due to: \(error)")
            return nil
        }
    }
    
    fileprivate func listenToCloudKitEvents() {
        // Register for changes to iCloud Account status when the app is running
        synchronizationLock.lock()
        defer { synchronizationLock.unlock() }
        guard !listeningToCloudKitEvents else {
            return
        }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(accountChanged(_:)),
                                               name: Notification.Name.CKAccountChanged,
                                               object: nil)
        listeningToCloudKitEvents = true
    }

    // MARK: - CloudKit completion adapters (iOS 15 / tvOS 15 APIs)

    // Adapt CloudKit's Result-based callbacks to the aggregate completion contract.
    // Surface individual item errors as CKError.partialFailure.

    private func setModifySubscriptionsCompletion(_ operation: CKModifySubscriptionsOperation, completion: @escaping ([CKSubscription]?, [CKSubscription.ID]?, Error?) -> Void) {
        var saved: [CKSubscription] = []
        var deleted: [CKSubscription.ID] = []
        let itemErrors = CloudKitItemFailureCollector()
        operation.perSubscriptionSaveBlock = { subscriptionID, result in
            switch result {
            case .success(let subscription):
                saved.append(subscription)
            case .failure(let error):
                itemErrors.record(itemID: subscriptionID, error: error)
            }
        }
        operation.perSubscriptionDeleteBlock = { subscriptionID, result in
            switch result {
            case .success:
                deleted.append(subscriptionID)
            case .failure(let error):
                itemErrors.record(itemID: subscriptionID, error: error)
            }
        }
        operation.modifySubscriptionsResultBlock = { result in
            completion(saved, deleted, CloudKitLegacyCompletion.combinedError(operationResult: result, itemErrors: itemErrors.snapshot))
        }
    }

    private func setFetchRecordZonesCompletion(_ operation: CKFetchRecordZonesOperation, completion: @escaping ([CKRecordZone.ID : CKRecordZone]?, Error?) -> Void) {
        var zones: [CKRecordZone.ID : CKRecordZone] = [:]
        let itemErrors = CloudKitItemFailureCollector()
        operation.perRecordZoneResultBlock = { zoneID, result in
            switch result {
            case .success(let zone):
                zones[zoneID] = zone
            case .failure(let error):
                itemErrors.record(itemID: zoneID, error: error)
            }
        }
        operation.fetchRecordZonesResultBlock = { result in
            completion(zones, CloudKitLegacyCompletion.combinedError(operationResult: result, itemErrors: itemErrors.snapshot))
        }
    }

    private func setModifyRecordZonesCompletion(_ operation: CKModifyRecordZonesOperation, completion: @escaping ([CKRecordZone]?, [CKRecordZone.ID]?, Error?) -> Void) {
        var saved: [CKRecordZone] = []
        var deleted: [CKRecordZone.ID] = []
        let itemErrors = CloudKitItemFailureCollector()
        operation.perRecordZoneSaveBlock = { zoneID, result in
            switch result {
            case .success(let zone):
                saved.append(zone)
            case .failure(let error):
                itemErrors.record(itemID: zoneID, error: error)
            }
        }
        operation.perRecordZoneDeleteBlock = { zoneID, result in
            switch result {
            case .success:
                deleted.append(zoneID)
            case .failure(let error):
                itemErrors.record(itemID: zoneID, error: error)
            }
        }
        operation.modifyRecordZonesResultBlock = { result in
            completion(saved, deleted, CloudKitLegacyCompletion.combinedError(operationResult: result, itemErrors: itemErrors.snapshot))
        }
    }

    private func setRecordWasChanged(_ operation: CKFetchRecordZoneChangesOperation, completion: @escaping (CKRecord) -> Void) {
        let itemErrors = CloudKitItemFailureCollector.associated(with: operation)
        operation.recordWasChangedBlock = { recordID, result in
            switch result {
            case .success(let record):
                completion(record)
            case .failure(let error):
                itemErrors.record(itemID: recordID, error: error)
            }
        }
    }

    private func setRecordZoneChangeTokensUpdated(_ operation: CKFetchRecordZoneChangesOperation, completion: @escaping (CKRecordZone.ID, CKServerChangeToken?, Data?) -> Void) {
        let itemErrors = CloudKitItemFailureCollector.associated(with: operation)
        operation.recordZoneChangeTokensUpdatedBlock = { zoneID, serverChangeToken, clientChangeTokenData in
            guard CloudKitLegacyCompletion.shouldForwardChangeTokenUpdate(itemErrors: itemErrors.snapshot) else {
                return
            }
            completion(zoneID, serverChangeToken, clientChangeTokenData)
        }
    }

    private func setRecordZoneFetchCompletion(_ operation: CKFetchRecordZoneChangesOperation, completion: @escaping (CKRecordZone.ID, CKServerChangeToken?, Data?, Bool, Error?) -> Void) {
        let itemErrors = CloudKitItemFailureCollector.associated(with: operation)
        operation.recordZoneFetchResultBlock = { zoneID, result in
            switch result {
            case .success(let fetchResult):
                // Keep token / moreComing values, but do not let a batch with
                // per-record failures look like success (caller will not persist the token).
                completion(zoneID,
                           fetchResult.serverChangeToken,
                           fetchResult.clientChangeTokenData,
                           fetchResult.moreComing,
                           CloudKitLegacyCompletion.partialFailureError(itemErrors.snapshot))
            case .failure(let error):
                completion(zoneID, nil, nil, false, error)
            }
        }
    }

    private func setFetchRecordZoneChangesCompletion(_ operation: CKFetchRecordZoneChangesOperation, completion: @escaping (Error?) -> Void) {
        let itemErrors = CloudKitItemFailureCollector.associated(with: operation)
        operation.fetchRecordZoneChangesResultBlock = { result in
            completion(CloudKitLegacyCompletion.combinedError(operationResult: result, itemErrors: itemErrors.snapshot))
        }
    }

    private func setFetchRecordsCompletion(_ operation: CKFetchRecordsOperation, completion: @escaping ([CKRecord.ID : CKRecord]?, Error?) -> Void) {
        var records: [CKRecord.ID : CKRecord] = [:]
        let itemErrors = CloudKitItemFailureCollector()
        operation.perRecordResultBlock = { recordID, result in
            switch result {
            case .success(let record):
                records[recordID] = record
            case .failure(let error):
                itemErrors.record(itemID: recordID, error: error)
            }
        }
        operation.fetchRecordsResultBlock = { result in
            completion(records, CloudKitLegacyCompletion.combinedError(operationResult: result, itemErrors: itemErrors.snapshot))
        }
    }

    private func setRecordMatched(_ operation: CKQueryOperation, completion: @escaping (CKRecord) -> Void) {
        let itemErrors = CloudKitItemFailureCollector.associated(with: operation)
        operation.recordMatchedBlock = { recordID, result in
            switch result {
            case .success(let record):
                completion(record)
            case .failure(let error):
                itemErrors.record(itemID: recordID, error: error)
            }
        }
    }

    private func setQueryCompletion(_ operation: CKQueryOperation, completion: @escaping (CKQueryOperation.Cursor?, Error?) -> Void) {
        let itemErrors = CloudKitItemFailureCollector.associated(with: operation)
        operation.queryResultBlock = { result in
            switch result {
            case .success(let cursor):
                completion(cursor, CloudKitLegacyCompletion.partialFailureError(itemErrors.snapshot))
            case .failure(let error):
                completion(nil, error)
            }
        }
    }

    private func setModifyRecordsCompletion(_ operation: CKModifyRecordsOperation, completion: @escaping ([CKRecord]?, [CKRecord.ID]?, Error?) -> Void) {
        var saved: [CKRecord] = []
        var deleted: [CKRecord.ID] = []
        let itemErrors = CloudKitItemFailureCollector()
        operation.perRecordSaveBlock = { recordID, result in
            switch result {
            case .success(let record):
                saved.append(record)
            case .failure(let error):
                itemErrors.record(itemID: recordID, error: error)
            }
        }
        operation.perRecordDeleteBlock = { recordID, result in
            switch result {
            case .success:
                deleted.append(recordID)
            case .failure(let error):
                itemErrors.record(itemID: recordID, error: error)
            }
        }
        operation.modifyRecordsResultBlock = { result in
            completion(saved, deleted, CloudKitLegacyCompletion.combinedError(operationResult: result, itemErrors: itemErrors.snapshot))
        }
    }

    private func beginStarting() -> Bool {
        synchronizationLock.lock()
        defer { synchronizationLock.unlock() }
        guard !starting else {
            startupRequested = recoverPurgedStore
            return false
        }
        starting = true
        return true
    }

    private func finishStarting() {
        synchronizationLock.lock()
        starting = false
        let shouldRestart = startupRequested
        startupRequested = false
        synchronizationLock.unlock()

        if shouldRestart {
            DispatchQueue.main.async {
                guard UIApplication.shared.applicationState != .background else { return }
                self.start(nil)
            }
        }
    }
}

private enum CloudKitPrinterSyncError: Error {
    case saveFailed(String)
    case stalePrinterSnapshot
    case invalidRecordData
    case missingCloudKitResult
    case syncUnavailable
}

struct CloudKitPrinterPullProgress {
    var printersChanged = false
    var localError: Error?
    var zoneError: Error?
    var checkpoint: Data?

    /// Only a complete pull can publish its proposed checkpoint. Previously
    /// committed records are safe to replay from the last saved token.
    func finish(operationError: Error?, saveCheckpoint: (Data) -> Void) -> Error? {
        if let error = localError ?? zoneError ?? operationError { return error }
        if let checkpoint { saveCheckpoint(checkpoint) }
        return nil
    }
}

/// Reconstructs the deprecated CloudKit aggregate-completion contract from modern
/// operation-level `Result` plus collected per-item failures.
enum CloudKitLegacyCompletion {
    static func partialFailureError(_ errorsByItemID: [AnyHashable: Error]) -> Error? {
        guard !errorsByItemID.isEmpty else {
            return nil
        }
        return CKError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: errorsByItemID])
    }

    static func combinedError(operationError: Error?, itemErrors: [AnyHashable: Error]) -> Error? {
        if let operationError {
            return operationError
        }
        return partialFailureError(itemErrors)
    }

    static func combinedError(operationResult: Result<Void, Error>, itemErrors: [AnyHashable: Error]) -> Error? {
        switch operationResult {
        case .success:
            return partialFailureError(itemErrors)
        case .failure(let error):
            return error
        }
    }

    /// Token updates from a zone-change operation must not be forwarded once any
    /// per-record failure has been collected for that operation.
    static func shouldForwardChangeTokenUpdate(itemErrors: [AnyHashable: Error]) -> Bool {
        itemErrors.isEmpty
    }
}

private var cloudKitItemFailureCollectorAssociatedKey: UInt8 = 0

/// Thread-safe collector for per-item CloudKit failures.
/// Associated with a `CKOperation` when multiple modern callbacks must share state
/// (zone-change record/zone/final completions, and query match/result completions).
final class CloudKitItemFailureCollector {
    private let lock = NSLock()
    private var errors: [AnyHashable: Error] = [:]

    func record(itemID: AnyHashable, error: Error) {
        lock.lock()
        errors[itemID] = error
        lock.unlock()
    }

    var snapshot: [AnyHashable: Error] {
        lock.lock()
        defer { lock.unlock() }
        return errors
    }

    static func associated(with operation: CKOperation) -> CloudKitItemFailureCollector {
        if let existing = objc_getAssociatedObject(operation, &cloudKitItemFailureCollectorAssociatedKey) as? CloudKitItemFailureCollector {
            return existing
        }
        let collector = CloudKitItemFailureCollector()
        objc_setAssociatedObject(operation, &cloudKitItemFailureCollectorAssociatedKey, collector, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return collector
    }
}


extension CKError {
    public func isRecordNotFound() -> Bool {
        return isZoneNotFound() || isUnknownItem()
    }
    
    public func isZoneNotFound() -> Bool {
        return isSpecificErrorCode(code: .zoneNotFound)
    }
    
    public func isUserDeletedZone() -> Bool {
        return isSpecificErrorCode(code: .userDeletedZone)
    }
    
    // Stored token for incremental reads is no longer good. We need to drop it and start from scratch
    public func isChangeTokenExpired() -> Bool {
        return isSpecificErrorCode(code: .changeTokenExpired)
    }
    
    public func isUnknownItem() -> Bool {
        return isSpecificErrorCode(code: .unknownItem)
    }
    
    public func isConflict() -> Bool {
        return isSpecificErrorCode(code: .serverRecordChanged)
    }
    
    public func isSpecificErrorCode(code: CKError.Code) -> Bool {
        var match = false
        if self.code == code {
            match = true
        }
        else if self.code == .partialFailure {
            // This is a multiple-issue error. Check the underlying array
            // of errors to see if it contains a match for the error in question.
            guard let errors = partialErrorsByItemID else {
                return false
            }
            for (_, error) in errors {
                if let cke = error as? CKError {
                    if cke.code == code {
                        match = true
                        break
                    }
                }
            }
        }
        return match
    }
    
    // ServerRecordChanged errors contain the CKRecord information
    // for the change that failed, allowing the client to decide
    // upon the best course of action in performing a merge.
    public func getMergeRecords() -> (CKRecord?, CKRecord?) {
        if code == .serverRecordChanged {
            // This is the direct case of a simple serverRecordChanged Error.
            return (clientRecord, serverRecord)
        }
        guard code == .partialFailure else {
            return (nil, nil)
        }
        guard let errors = partialErrorsByItemID else {
            return (nil, nil)
        }
        for (_, error) in errors {
            if let cke = error as? CKError {
                if cke.code == .serverRecordChanged {
                    // This is the case of a serverRecordChanged Error
                    // contained within a multi-error PartialFailure Error.
                    return cke.getMergeRecords()
                }
            }
        }
        return (nil, nil)
    }
}

struct PrinterData {
    var printerID: NSManagedObjectID
    var name: String
    var hostname: String
    var apiKey: String
    var connectionType: Int16
    var position: Int16
    var username: String?
    var password: String?
    var headers: String?
    var userModified: Date?
    var recordData: Data?

    /// Compare the locally persisted fields with the values captured for this push.
    func differsFromLocalFields(of printer: Printer) -> Bool {
        name != printer.name ||
        hostname != printer.hostname ||
        apiKey != printer.apiKey ||
        connectionType != printer.connectionType ||
        position != printer.position ||
        username != printer.username ||
        password != printer.password ||
        headers != printer.headers ||
        userModified != printer.userModified
    }
}
