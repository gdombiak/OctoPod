//
//  AppDelegate.swift
//  OctoPod TV
//
//  Created by Gaston Dombiak on 2/21/20.
//  Copyright © 2020 Gaston Dombiak. All rights reserved.
//

import UIKit
import CoreData

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Keep the TV awake while displaying print progress.
        application.isIdleTimerDisabled = true
        return true
    }

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentContainer(name: "OctoPod")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                 
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

    // MARK: - My extensions

    lazy var printerManager: PrinterManager? = {
        let context = persistentContainer.viewContext
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        var printerManager = PrinterManager(managedObjectContext: context, persistentContainer: persistentContainer)
        return printerManager
    }()

    lazy var cloudKitPrinterManager: CloudKitPrinterManager = {
       return CloudKitPrinterManager(printerManager: self.printerManager!)
    }()

    lazy var appConfiguration: AppConfiguration = {
        return AppConfiguration()
    }()
    
    lazy var tvPrinterManager: TVPrinterManager = {
        return TVPrinterManager(printerManager: self.printerManager!, cloudKitPrinterManager: self.cloudKitPrinterManager)
    }()

}

