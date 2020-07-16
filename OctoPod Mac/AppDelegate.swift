//
//  AppDelegate.swift
//  OctoPod Mac
//
//  Created by Arijit Banerjee on 6/26/20.
//  Copyright © 2020 Gaston Dombiak. All rights reserved.
//

import Cocoa
import UserNotifications

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    lazy var preferencesWindowController = { () -> NSWindowController in
        let storyBoard = NSStoryboard(name: "Main", bundle: nil)
        guard let pwc = storyBoard.instantiateController(withIdentifier: "PreferencesWindowController") as? NSWindowController else{
            fatalError("Unable to instantiate view controller")
        }
        (pwc.contentViewController as! PreferencesViewController).delegate = popoverViewController
        return pwc
    }()
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    
    lazy var popoverViewController = { () -> PopoverViewController in
        let storyBoard = NSStoryboard(name: "Main", bundle: nil)
        guard let vc = storyBoard.instantiateController(withIdentifier: "PopoverViewController") as? PopoverViewController
            else{
            fatalError("Unable to instantiate view controller")
        }
        return vc
    }()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if #available(OSX 10.14, *) {
            registerForPushNotifications()
        } else {
            // Fallback on earlier versions
        }
        let itemImage = NSImage(named: NSImage.Name("Status-Icon"))
        itemImage?.size = NSMakeSize(20.0, 20.0);
        itemImage?.isTemplate = true
        statusItem.button?.image = itemImage
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusBarButtonClicked)
        statusItem.button?.toolTip = "OctoPod for OctoPrint"
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    lazy var appConfiguration: AppConfiguration = {
        return AppConfiguration()
    }()
    func showQuickView()  {
        guard let button = statusItem.button else {
            fatalError("Cannot get status button")
        }
        let popoverView = NSPopover()
        popoverView.contentViewController = popoverViewController
        popoverView.behavior = .transient
        popoverView.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
    }
    
    @objc func showPreferences() {
        preferencesWindowController.showWindow(self)
    }
    
    lazy var menu = getMenu()
    private func getMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "About OctoPod Mac", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Preferences", action: #selector(showPreferences), keyEquivalent: "P"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit OctoPod Mac", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }
    
    @objc func statusBarButtonClicked(sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        if event.type == NSEvent.EventType.rightMouseUp {
            NSMenu.popUpContextMenu(menu, with: event, for: sender)
        } else {
            showQuickView()
        }
    }
    @available(OSX 10.14, *)
    func registerForPushNotifications() {
        UNUserNotificationCenter.current() // 1
            .requestAuthorization(options: [.alert, .sound, .badge]) { // 2
                granted, error in
                guard granted else { return }
                self.getNotificationSettings()
        }
    }

    @available(OSX 10.14, *)
    func getNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            NSLog("Notification settings: \(settings)")
        }
    }
    
    lazy var printerManager: PrinterManager? = {
        let context = persistentContainer.viewContext
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        var printerManager = PrinterManager()
        printerManager.managedObjectContext = context
        return printerManager
    }()
    
    // MARK: - Core Data stack

    lazy var persistentContainer: SharedPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = SharedPersistentContainer(name: "OctoPod")
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
    
    @IBAction func preferencesFromMainMenuClicked(_ sender: Any) {
        showPreferences()
    }
    
}


