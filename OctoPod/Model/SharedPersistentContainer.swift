import Foundation
import CoreData

class SharedPersistentContainer: NSPersistentContainer {
    
    override class func defaultDirectoryURL() -> URL{
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.octopod.SharingData")!
    }
    
    override init(name: String, managedObjectModel model: NSManagedObjectModel) {
        super.init(name: name, managedObjectModel: model)
    }
    
    static func deleteOldLocalStore(oldStoreUrl: URL) {
        let fileCoordinator = NSFileCoordinator(filePresenter: nil)
        fileCoordinator.coordinate(writingItemAt: oldStoreUrl, options: .forDeleting, error: nil, byAccessor: {
            (urlForModifying) -> Void in
            do {
                try FileManager.default.removeItem(at: urlForModifying)
            }catch let error {
                print("Failed to remove item with error: \(error.localizedDescription)")
            }
        })
    }
}
