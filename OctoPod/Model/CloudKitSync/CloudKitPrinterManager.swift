import Foundation
import CloudKit

class CloudKitPrinterManager {

    private let SYNC_STOPPED = "CK_SYNC_STOPPED"  // Key to track if CloudKit sync is enabled or not in the app. Controlled by user from the app. Do not confuse with 'is user logged into iCloud'
    private var iCloudAvailable = true // Assume default value. Will be updated with real one on start up and based on events
    
    let SUBSCRIPTION_ID = "SUBSCRIPTION_ID"  // ID of one time subcription to receive push notifications
    private let SUBSCRIPTION_CREATED = "CK_SUBSCRIPTION_CREATED"  // Key to track creation of one time subcription to receive push notifications
    private let CHANGE_TOKEN = "CK_CHANGE_TOKEN" // Key to use for storing token that tracks last processed changes from CloudKit server

    private let RECORD_TYPE = "OctoPrint"
    private let zoneID = CKRecordZone.ID(zoneName: "MyOctoPod", ownerName: CKCurrentUserDefaultName)

    private let printerManager: PrinterManager!
    private var starting = false
    
    var delegates: Array<CloudKitPrinterDelegate> = Array()
    var logDelegates: Array<CloudKitPrinterLogDelegate> = Array()
    
    // Keep a log of events that happend. Log will only keep a certain number of entries to preserve memory
    private(set) var log: Array<CloudKitPrinterLogEntry> = Array()
    private let LOG_MAX_SIZE = 30

    init(printerManager: PrinterManager) {
        self.printerManager = printerManager

        // Register for changes to iCloud Account status when the app is running
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(start),
                                               name: Notification.Name.CKAccountChanged,
                                               object: nil)
    }

    // MARK: - Start
    
    // Start synchronizing with iCloud (if available)
    @objc func start() {
        if starting {
            // Do nothing since we are already starting
            return
        }
        starting = true // Mark that we are starting
        discoverAccountStatus {
            if self.iCloudAvailable {
                // Wait 500ms before pushing local changes (of printers) to CloudKit (to sync other devices)
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5) {
                    // Make sure that we have a subscription to CloudKit changes (so we can listen
                    // when other devices of the same user, that is logged in iCloud, change their printers information)
                    self.checkNotificationsSubscription()
                    
                    self.checkZone(completion: { (error) in
                        if let error = error {
                            self.appendLog("Error making sure app has its own CKRecordZone. \(error.localizedDescription)")
                            self.starting = false
                        } else {
                            // Pull printer updates from iCloud and then push local printer changes to iCloud
                            // If existing printers were never pushed to iCloud then pulling will update
                            // printers with information. Push will end up pushing only printers that were
                            // not present in inCloud or that were changed while not connected to iCloud
                            // or that failed previously
                            self.pullChanges(completionHandler: {
                                self.pushChanges(completion: {
                                    self.starting = false
                                })
                            }, errorHandler: {
                                self.starting = false
                                // Do nothing
                            })
                        }
                    })
                }
            } else {
                self.starting = false
            }
        }
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
        let defaults = UserDefaults.standard
        defaults.set(stop, forKey: SYNC_STOPPED)
    }

    // Returns true if user does not allow device synchronizion (via iCloud)
    // User can allow device synchronization but they need to be logged into
    // iCloud for this to work
    func cloudKitSyncStopped() -> Bool {
        let defaults = UserDefaults.standard
        return defaults.bool(forKey: SYNC_STOPPED)
    }
    
    // MARK: Subscription operations
    
    // Create a one time subscription to get silent push notifications when other devices make changes to CloudKit records
    // AppDelegate is configured to request to "listen to remote notifications" and call into #handleNotifications()
    fileprivate func checkNotificationsSubscription() {
        let defaults = UserDefaults.standard
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
            operation.modifySubscriptionsCompletionBlock = { (saved: [CKSubscription]?, deletedIDs: [String]?, error: Error?) -> Void in
                if let error = error {
                    self.appendLog("Error saving subcription: \(error.localizedDescription)")
                    return
                }
                // Record that (one time) subscription has been created
                defaults.set(true, forKey: self.SUBSCRIPTION_CREATED)
            }
            operation.qualityOfService = .utility
                        
            let container = getiCloudContainer()
            let db = container.privateCloudDatabase
            db.add(operation)
        }
    }
    
    // MARK: - Zone operations
    
    fileprivate func checkZone(completion: @escaping (Error?) -> Void) {
        // Check that we have our custom zone
        let operation = CKFetchRecordZonesOperation(recordZoneIDs: [zoneID])
        operation.fetchRecordZonesCompletionBlock = { recordZonesByZoneID, error in
            if let error = error {
                if let ckerror = error as? CKError {
                    if ckerror.isZoneNotFound() || ckerror.isUserDeletedZone() {
                        self.createZone(completion: { (error) in
                            if let error = error {
                                // Failed to create zone
                                completion(error)
                            } else {
                                // Zone created
                                // Mark all printers as need to be updated in iCloud
                                self.printerManager.resetPrintersForiCloud(context: self.printerManager.newPrivateContext())
                                // Reset change token since it is no longer valid
                                UserDefaults.standard.removeObject(forKey: self.CHANGE_TOKEN)
                                // We can now execute completion block
                                completion(nil)
                            }
                        })
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
        let container = getiCloudContainer()
        let db = container.privateCloudDatabase
        db.add(operation)
    }

    // Create a custom zone where we store our records. We need to use a custom zone
    // and not the default one since we are doing incremental reads which is not supported
    // in default zone
    fileprivate func createZone(completion: @escaping (Error?) -> Void) {
        let recordZone = CKRecordZone(zoneID: zoneID)
        let operation = CKModifyRecordZonesOperation(recordZonesToSave: [recordZone], recordZoneIDsToDelete: [])
        operation.modifyRecordZonesCompletionBlock = { savedRecordZones, deletedRecordZoneIDs, error in
            guard error == nil else {
                completion(error)
                return
            }
            self.appendLog("Zone created")
            completion(nil)
        }
        operation.qualityOfService = .utility
        let container = getiCloudContainer()
        let db = container.privateCloudDatabase
        db.add(operation)
    }
    
    fileprivate func deleteZone(completion: @escaping (Error?) -> Void) {
        let operation = CKModifyRecordZonesOperation(recordZonesToSave: [], recordZoneIDsToDelete: [zoneID])
        operation.modifyRecordZonesCompletionBlock = { savedRecordZones, deletedRecordZoneIDs, error in
            guard error == nil else {
                completion(error)
                return
            }
            self.appendLog("Zone deleted")
            completion(nil)
        }
        operation.qualityOfService = .utility
        let container = getiCloudContainer()
        let db = container.privateCloudDatabase
        db.add(operation)
    }
    
    // MARK: - Pull from iCloud
    
    // Pull incremental changes since last pull
    // Printers stored in Core Data will get updated based on iCloud information
    func pullChanges(completionHandler: (() -> Void)?, errorHandler: (() -> Void)?) {
        // If user disabled CloudKit sync then do nothing
        if cloudKitSyncStopped() || !iCloudAvailable {
            completionHandler?()
            return
        }
        var foundNewRecords = false
        let defaults = UserDefaults.standard
        var changeToken: CKServerChangeToken? = nil
        // Retrieve stored token that tracks last set of changes that were processed.
        // Used for incremental reading
        if let changeTokenData = defaults.data(forKey: CHANGE_TOKEN) {
            // Parse stored token
            changeToken = NSKeyedUnarchiver.unarchiveObject(with: changeTokenData) as! CKServerChangeToken?
        }
        // Include change token in the query to get incremental changes
        // If nil then we will get everything
        let options = CKFetchRecordZoneChangesOperation.ZoneOptions()
        options.previousServerChangeToken = changeToken
        // Prepare query to custom zone and ask to get new changes (i.e. iterate through pagination transparently)
        let optionsMap = [zoneID: options]
        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zoneID], optionsByRecordZoneID: optionsMap)
        operation.fetchAllChanges = true
        // Block to process created or updated records
        operation.recordChangedBlock = { record in
            foundNewRecords = true
            self.recordChanged(record: record)
        }
        // Block to process deleted records
        operation.recordWithIDWasDeletedBlock = { recordID, recordType in
            foundNewRecords = true
            self.recordDeleted(recordID: recordID)
        }
        // Block that records change token (to track how far we read so we can do next incremental read)
        operation.recordZoneChangeTokensUpdatedBlock = { recordZoneID, serverChangeToken, clientChangeTokenData in
            guard let serverChangeToken = serverChangeToken else {
                return
            }
            
            let changeTokenData = NSKeyedArchiver.archivedData(withRootObject: serverChangeToken)
            defaults.set(changeTokenData, forKey: self.CHANGE_TOKEN)
        }
        // Block to execute when the fetch for a zone "page" has completed
        // Works like pagination so more might be coming
        operation.recordZoneFetchCompletionBlock = { recordZoneID, serverChangeToken, clientChangeTokenData, moreComing, error in
            if let error = error {
                if let ckerror = error as? CKError {
                    if ckerror.isZoneNotFound() || ckerror.isUserDeletedZone() {
                        // ZoneNotFound is the one error we can reasonably expect & handle here, since
                        // the zone isn't created automatically for us until we've saved one record.
                        // create the zone and, if successful, try again
                        self.createZone() { error in
                            if let error = error {
                                // Failed to create zone for some reason
                                self.appendLog("Error fetching zone changes. Failed to create zone due to: \(error.localizedDescription)")
                                return
                            } else {
                                // Zone created
                                // Mark all printers as need to be updated in iCloud
                                self.printerManager.resetPrintersForiCloud(context: self.printerManager.newPrivateContext())
                                // Reset change token since it is no longer valid
                                UserDefaults.standard.removeObject(forKey: self.CHANGE_TOKEN)
                                // Cancel this operation
                                operation.cancel()
                                // Zone created. Retry operation
                                self.pullChanges(completionHandler: completionHandler, errorHandler: errorHandler)
                            }
                        }
                    } else if ckerror.isChangeTokenExpired() {
                        // Token for incremental reads is no longer good. We need start from scratch
                        // Mark all printers as need to be updated in iCloud
                        self.printerManager.resetPrintersForiCloud(context: self.printerManager.newPrivateContext())
                        // Reset change token since it is no longer valid
                        UserDefaults.standard.removeObject(forKey: self.CHANGE_TOKEN)
                        // Cancel this operation
                        operation.cancel()
                        // Retry operation
                        self.pullChanges(completionHandler: completionHandler, errorHandler: errorHandler)
                    } else {
                        // Failed with some unknown CKError
                        self.appendLog("Error fetching zone changes: \(error.localizedDescription)")
                        return
                    }
                } else {
                    // Failed with some unknown Error
                    self.appendLog("Error fetching zone changes: \(error.localizedDescription)")
                    return
                }
            }
            guard let serverChangeToken = serverChangeToken else {
                return
            }
            
            let changeTokenData = NSKeyedArchiver.archivedData(withRootObject: serverChangeToken)
            defaults.set(changeTokenData, forKey: self.CHANGE_TOKEN)
        }
        // Done reading all zone changes
        operation.fetchRecordZoneChangesCompletionBlock = { (error) in
            if error == nil {
                // Success. New data was downloaded
                completionHandler?()
                if foundNewRecords {
                    // Alert delegates that printers have been updated
                    self.notifyPrintersUpdated()
                }
            }
        }
        operation.qualityOfService = .utility
        
        let container = getiCloudContainer()
        let db = container.privateCloudDatabase
        db.add(operation)
    }

    // CloudKit informed us that a record has been created or updated
    fileprivate func recordChanged(record: CKRecord) {
        let recordName = record.recordID.recordName
        if let printer = printerManager.getPrinterByRecordName(recordName: recordName) {
            // A printer exists for this PK so update it
            updateAndSave(printer: printer, serverRecord: record)
            // Alert delegates that printer has been updated from iCloud info
            notifyPrinterUpdated(printer: printer)
            appendLog("Updated printer: \(printer.hostname)")
        } else {
            // No printer was found for this PK
            // Check if a printer with same data exists and no record name.
            if let printer = printerManager.getPrinters().first(where: { (printer: Printer) -> Bool in
                return self.sameOctoPrint(record: record, printer: printer)
            }) {
                // Update printer with iCloud information and save it
                updateAndSave(printer: printer, serverRecord: record)
                // Alert delegates that printer has been updated from iCloud info
                notifyPrinterUpdated(printer: printer)
                appendLog("Linked existing printer: \(printer.hostname)")
            } else {
                // Nothing was found in Core Data so create new printer and add to Core Data
                let parsed = parseRecord(record: record)
                if let name = parsed.name, let hostname = parsed.hostname, let apiKey = parsed.apiKey {
                    let position = Int16(printerManager.getPrinters().count)  // Not transfering position information via iCloud (reducing work scope) so add new printers to bottom of list
                    if printerManager.addPrinter(name: name, hostname: hostname, apiKey: apiKey, username: parsed.username, password: parsed.password, position: position, iCloudUpdate: false, modified: (parsed.modified == nil ? Date() : parsed.modified!)) {
                        if let printer = printerManager.getPrinterByName(name: name) {
                            // Update again to assign recordName and store encoded record
                            updateAndSave(printer: printer, serverRecord: record)
                            // Alert delegates that printer has been added from iCloud info
                            notifyPrinterAdded(printer: printer)
                            appendLog("Added new printer: \(printer.hostname)")
                        } else {
                            appendLog("Missing newly added printer: \(hostname)")
                        }
                    } else {
                        appendLog("Failed to add printer for record name: \(record.recordID.recordName)")
                    }
                } else {
                    appendLog("Ignored record name: \(record.recordID.recordName)")
                }
            }
        }
    }
    
    
    // CloudKit informed us that a record has been deleted
    fileprivate func recordDeleted(recordID: CKRecord.ID) {
        let recordName = recordID.recordName
        if let printer = printerManager.getPrinterByRecordName(recordName: recordName) {
            appendLog("Deleted printer: \(printer.hostname)")
            // A printer exists for this PK so delete it
            let newObjectContext = printerManager.newPrivateContext()
            let printerToDelete = newObjectContext.object(with: printer.objectID) as! Printer
            printerManager.deletePrinter(printerToDelete, context: newObjectContext)
            // Alert delegates that printer has been deleted from iCloud info
            notifyPrinterDeleted(printer: printer)
        }
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
        // If user disabled CloudKit sync then do nothing
        if cloudKitSyncStopped() || !iCloudAvailable {
            return
        }
        var toRemove: Array<Printer> = Array()
        for printer in printerManager.getPrinters() {
            if printer.iCloudUpdate {
                toRemove.append(printer)
            }
        }
        pushChange(index: 0, toRemove: toRemove, completion: completion)
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
                deleteRecord(recordID: record.recordID) { (error) in
                    if let error = error {
                        self.appendLog("Failed to delete printer: \(hostname). Error: \(error.localizedDescription)")
                    } else {
                        self.appendLog("Pushed delete for printer: \(hostname)")
                    }
                }
            }
        }
    }
    
    // Push one at a time to prevent concurrency issues with Core Data
    fileprivate func pushChange(index: Int, toRemove: Array<Printer>, completion: (() -> Void)?) {
        if index < toRemove.count {
            let printer = toRemove[index]
            self.save(printer: printer, completion: { error in
                if let error = error {
                    self.appendLog("Failed to push changes for printer: \(printer.hostname). Error: \(error.localizedDescription)")
                } else {
                    self.appendLog("Pushed changes for printer: \(printer.hostname)")
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
    fileprivate func save(printer: Printer, completion: ((Error?) -> Void)?) {
        if let recordData = printer.recordData {
            // Printer was once stored in iCloud. Decode encoded CloudKit record stored in the printer
            if let record = decodeRecordData(recordData: recordData) {
                // Update record with printer information. Record got last updated when stored
                // in iCloud, this is why we need to update it with new printer data
                self.updateRecordFields(record: record, from: printer)
                // Save record to iCloud (and do any merge if needed)
                saveAndMerge(record: record) { serverRecord, originalUpdated, error in
                    if let error = error {
                        // Failed to save to iCloud
                        completion?(error)
                    } else if let newRecord = serverRecord {
                        // Record has been saved
                        self.updateAndSave(printer: printer, serverRecord: newRecord)
                        // Execute callback
                        completion?(nil)

                        if originalUpdated {
                            // Record has been updated with iCloud information
                            // During the save we found another version on the server side and
                            // the merging logic determined we should update our local data to match
                            // what was in the iCloud database.
                            self.notifyPrinterUpdated(printer: printer)
                        }
                    } else {
                        // Should not happen
                        NSLog("No error and no CloudKit CKRecord")
                    }
                }
            } else {
                // We have a bug Houston!
                NSLog("Failed to decode encoded CloudKit CKRecord")
            }
        } else {
            // We don’t already have a record. See if there’s one up on iCloud
            self.queryRecord(hostname: printer.hostname, apiKey: printer.apiKey) { (records: [CKRecord]?, error: Error?) in
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
                        self.updateRecordFields(record: record, from: printer)
                        // Save new record
                        self.saveRecord(record: record, completion: { (record: CKRecord?, error: Error?) in
                            if let error = error {
                                completion?(error)
                            } else if let newRecord = record {
                                // Record has been saved
                                self.updateAndSave(printer: printer, serverRecord: newRecord)
                                // Execute callback
                                completion?(nil)
                            } else {
                                // We have a bug Houston!
                                NSLog("No error and no new record")
                            }
                        })
                    } else {
                        // iCloud has similar info to this printer
                        // Check if we have a printer (stored in Core Data) for the records we found
                        for record in records {
                            if let _ = self.printerManager.getPrinterByRecordName(recordName: record.recordID.recordName) {
                                // We have at least 2 printers in Core Data for the same OctoPrint instance. Let's reduce duplication
                                // Keep the duplicate printer since it is already linked to iCloud and delete the printer we
                                // were requested to save to iCloud
                                let newObjectContext = self.printerManager.newPrivateContext()
                                let printerToDelete = newObjectContext.object(with: printer.objectID) as! Printer
                                self.printerManager.deletePrinter(printerToDelete, context: newObjectContext)
                                // Alert delegates that we had to delete this printer
                                self.notifyPrinterDeleted(printer: printer)
                                // Execute callback
                                completion?(nil)
                                // We are done
                                return
                            }
                        }
                        // Records didn't match to any Core Data. Instead of duplicating
                        // in iCloud, let's update printer and link it to existing iCloud record
                        self.updateAndSave(printer: printer, serverRecord: records[0])
                        // Alert delegates that we had to update this printer
                        self.notifyPrinterUpdated(printer: printer)
                        // Execute callback
                        completion?(nil)
                    }
                } else {
                    // We have a bug Houston!
                    NSLog("No error and no records!")
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
                    if (clientModified?.compare(serverModified!) == .orderedDescending) {
                        // We’ve decided ours is the winner, so do the update again
                        // using the current iCloud ServerRecord as the base CKRecord.
                        self.updateRecord(source: clientRecord, target: serverRecord)
                        serverRecord["modified"] = clientModified! as NSDate
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
        operation.fetchRecordsCompletionBlock = { records, error in
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
        
        let container = getiCloudContainer()
        let db = container.privateCloudDatabase
        db.add(operation)
    }
    
    // Query records from the iCloud database that match the specified criteria
    fileprivate func queryRecord(hostname: String, apiKey: String, completion: @escaping ([CKRecord]?, Error?) -> Void) {
        let predicate = NSPredicate(format: "hostname = %@ && apiKey = %@", hostname, apiKey)
        let query = CKQuery(recordType: RECORD_TYPE, predicate: predicate)
        let operation = CKQueryOperation(query: query)
        var result: Array<CKRecord> = Array()
        operation.recordFetchedBlock = { record in
            result.append(record)
        }
        operation.queryCompletionBlock = { cursor, error in
            if let error = error {
                completion(nil, error)
            } else if cursor == nil {
                // No more results. We are done
                completion(result, nil)
            }
        }
        operation.qualityOfService = .utility
        
        let container = getiCloudContainer()
        let db = container.privateCloudDatabase
        db.add(operation)
    }
    
    // Save a record to the iCloud database
    // Create zone if needed. Any other error is not handled and passed to completion block
    fileprivate func saveRecord(record: CKRecord, completion: @escaping (CKRecord?, Error?) -> Void) {
        let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: [])
        operation.modifyRecordsCompletionBlock = { (savedRecords: [CKRecord]?, deletedRecordIDs: [CKRecord.ID]?, error: Error?) in
            if let error = error {
                if let ckerror = error as? CKError {
                    if ckerror.isZoneNotFound() {
                        // ZoneNotFound is the one error we can reasonably expect & handle here, since
                        // the zone isn't created automatically for us until we've saved one record.
                        // create the zone and, if successful, try again
                        self.createZone() { error in
                            if let error = error {
                                // Failed to create zone for some reason
                                completion(nil, error)
                            } else {
                                // Zone created so save record now
                                self.saveRecord(record: record, completion: completion)
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
        
        let container = getiCloudContainer()
        let db = container.privateCloudDatabase
        db.add(operation)
    }
    
    fileprivate func deleteRecord(recordID: CKRecord.ID, completion: @escaping (Error?) -> Void) {
        let operation = CKModifyRecordsOperation(recordsToSave: [], recordIDsToDelete: [recordID])
        operation.modifyRecordsCompletionBlock = { (savedRecords: [CKRecord]?, deletedRecordIDs: [CKRecord.ID]?, error: Error?) in
            if let error = error {
                if let ckerror = error as? CKError {
                    if !ckerror.isZoneNotFound() {
                        // Failed with some unknown CKError
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
        
        let container = getiCloudContainer()
        let db = container.privateCloudDatabase
        db.add(operation)
    }

    // MARK: - Reset operations
    
    // Delete CloudKit records and recreate from local stored data
    func resetCloutKit(completionHandler: (() -> Void)?, errorHandler: (() -> Void)?) {
        // Delete zone which will delete all stored records
        deleteZone { (error: Error?) in
            if let error = error {
                NSLog("Deleting zone failed. Error: \(error.localizedDescription)")
                // Delete failed. An error happened when deleting the zone
                errorHandler?()
            } else {
                // Zone deleted so now create one
                // Pull just to force a new token for incremental reads. Nothing should be read
                self.pullChanges(completionHandler: {
                    self.pushChanges(completion: completionHandler)
                }, errorHandler: {
                    NSLog("Error pulling from iCloud during reset")
                    errorHandler?()
                })
            }
        }
    }
    
    /// Delete local stored data and recreate from CloudKit records
    func resetLocalPrinters(completionHandler: (() -> Void)?, errorHandler: (() -> Void)?) {
        // Delete local printers
        let newObjectContext = printerManager.newPrivateContext()
        printerManager.deleteAllPrinters(context: newObjectContext)
        // Delete CHANGE_TOKEN so all changes are fetched and processed
        UserDefaults.standard.removeObject(forKey: self.CHANGE_TOKEN)
        // Pull changes
        pullChanges(completionHandler: completionHandler, errorHandler: errorHandler)
    }

    // MARK: - Delegate notifications operations
    
    fileprivate func notifyPrintersUpdated() {
        // Alert delegates that printers have been updated
        for delegate in self.delegates {
            delegate.printersUpdated()
        }
    }
    
    fileprivate func notifyPrinterAdded(printer: Printer) {
        for delegate in self.delegates {
            delegate.printerAdded(printer: printer)
        }
    }
    
    fileprivate func notifyPrinterUpdated(printer: Printer) {
        for delegate in self.delegates {
            delegate.printerUpdated(printer: printer)
        }
    }
    
    fileprivate func notifyPrinterDeleted(printer: Printer) {
        for delegate in self.delegates {
            delegate.printerDeleted(printer: printer)
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
                    self.appendLog("Disabling iCloud sync due to error: \(error.localizedDescription)")
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
    
    /// Returns true if CKRecord and Printer represent same OctoPrint server
    fileprivate func sameOctoPrint(record: CKRecord, printer: Printer) -> Bool {
        if let ck_hostname = record["hostname"] as? String {
            if let recordName = printer.recordName {
                // Check that we have same PK and same hostname
                return printer.hostname == ck_hostname && recordName == record.recordID.recordName
            } else {
                // Only the same if no PK and same hostname
                return printer.hostname == ck_hostname && printer.recordName == nil
            }
        }
        return false
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
        printer.username = parsed.username
        printer.password = parsed.password
        // Updated from iCloud so reset this flag since there is no need to push this data to iCloud (until modified)
        printer.iCloudUpdate = false
        // Assign PK to associate with record
        printer.recordName = record.recordID.recordName
        // Encode record and store it in printer
        printer.recordData = encodeRecord(record: record)
    }
    
    fileprivate func updateRecordFields(record: CKRecord, from printer: Printer) {
        record["name"] = printer.name as NSString
        record["hostname"] = printer.hostname as NSString
        record["apiKey"] = printer.apiKey as NSString
        record["username"] = printer.username as NSString?
        record["password"] = printer.password as NSString?
        if let date = printer.userModified {
            record["modified"] = date as NSDate
        }
    }
    
    fileprivate func updateAndSave(printer: Printer, serverRecord: CKRecord) {
        let newObjectContext = printerManager.newPrivateContext()
        let printerToUpdate = newObjectContext.object(with: printer.objectID) as! Printer
        // This will encode new record data and also update last modified date (for future merges)
        self.updatePrinterFields(printer: printerToUpdate, from: serverRecord)
        // Update printer in Core Data
        self.printerManager.updatePrinter(printerToUpdate, context: newObjectContext)
    }
    
    fileprivate func parseRecord(record: CKRecord) -> (name: String?, hostname: String?, apiKey: String?, username: String?, password: String?, modified: Date?) {
        let name = record["name"] as? String
        let hostname = record["hostname"] as? String
        let apiKey = record["apiKey"] as? String
        let username = record["username"] as? String
        let password = record["password"] as? String
        let modified = record["modified"] as? Date
        return (name, hostname, apiKey, username, password, modified)
    }
    
    fileprivate func updateRecord(source: CKRecord, target: CKRecord) {
        target["name"] = source["name"]
        target["hostname"] = source["hostname"]
        target["apiKey"] = source["apiKey"]
        target["username"] = source["username"]
        target["password"] = source["password"]
    }
    
    fileprivate func encodeRecord(record: CKRecord) -> Data {
        let data = NSMutableData()
        let coder = NSKeyedArchiver.init(forWritingWith: data)
        coder.requiresSecureCoding = true
        record.encodeSystemFields(with: coder)
        coder.finishEncoding()
        return data as Data
    }

    fileprivate func decodeRecordData(recordData: Data) -> CKRecord? {
        // set up the CKRecord with its metadata
        let coder = NSKeyedUnarchiver(forReadingWith: recordData)
        coder.requiresSecureCoding = true
        let record = CKRecord(coder: coder)
        coder.finishDecoding()
        return record
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
