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
    
    @IBOutlet weak var statusMenu: NSMenu!
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    var viewController: ViewController!
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        registerForPushNotifications()
        let itemImage = NSImage(named: NSImage.Name("Octopod"))
        itemImage?.size = NSMakeSize(20.0, 20.0);
        itemImage?.isTemplate = true
        statusItem.button?.image = itemImage
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusBarButtonClicked)
        
        let storyBoard = NSStoryboard(name: "Main", bundle: nil)
        guard let vc = storyBoard.instantiateController(withIdentifier: "ViewController") as? ViewController else{
            fatalError("Unable to instantiate view controller")
        }
        viewController = vc
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
        popoverView.contentViewController = viewController
        popoverView.behavior = .transient
        popoverView.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
    }
    lazy var menu = getMenu()
    private func getMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "About OctoPod Mac", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Add 3D Printer", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "P"))
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
    func registerForPushNotifications() {
        UNUserNotificationCenter.current() // 1
            .requestAuthorization(options: [.alert, .sound, .badge]) { // 2
                granted, error in
                guard granted else { return }
                self.getNotificationSettings()
        }
    }
    func getNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("Notification settings: \(settings)")
        }
    }
}


