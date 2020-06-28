//
//  AppDelegate.swift
//  OctoPod Mac
//
//  Created by Arijit Banerjee on 6/26/20.
//  Copyright © 2020 Gaston Dombiak. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    var viewController: ViewController!
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let itemImage = NSImage(named: NSImage.Name("Octopod"))
        itemImage?.isTemplate = false
        //statusItem.button?.title = "A"
        statusItem.button?.image = itemImage
        statusItem.button?.target = self
        statusItem.button?.action = #selector(showDashboard)
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
    @objc func showDashboard()  {
        guard let button = statusItem.button else {
            fatalError("Cannot get status button")
        }
        let popoverView = NSPopover()
        popoverView.contentViewController = viewController
        popoverView.behavior = .transient
        popoverView.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
    }
    
    
    
}


