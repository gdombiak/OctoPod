//
//  ViewController.swift
//  OctoPod Mac
//
//  Created by Arijit Banerjee on 6/27/20.
//  Copyright © 2020 Gaston Dombiak. All rights reserved.
//

import Cocoa
import CoreData
import AVKit
class ViewController: NSViewController, OctoPrintClientDelegate {
    
    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var connectButton: NSButton!
    
    @IBOutlet weak var printerStatusLabel: NSTextField!
    
    @IBOutlet weak var printerStatusValue: NSTextField!
    private var serverConnected = false
    private var printerConnected: Bool?
    var streamingController: MjpegStreamingController?
    
    
    lazy var printerManager: PrinterManager? = {
        let context = persistentContainer.viewContext
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        var printerManager = PrinterManager()
        printerManager.managedObjectContext = context
        return printerManager
    }()
    
    
    lazy var octoPrintClient: OctoPrintClient = {
        let octoPrintClient = OctoPrintClient(printerManager: self.printerManager!)
        octoPrintClient.delegates.append(self)
        return octoPrintClient
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if !self.serverConnected{
            connectToServer()
        }
    streamingController = MjpegStreamingController(imageView: imageView)
        streamingController?.play(url: URL(string:"https://arijit.org/webcam/?action=stream")!)
    }
    
    func updatePrinterStatusView(printerStatus:String,extruderTemp:Double,bedTemp:Double){
        printerStatusValue.stringValue = printerStatus
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
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
    
    fileprivate func updateConnectButton(printerConnected: Bool, assumption: Bool) {
        DispatchQueue.main.async {
            if !printerConnected {
                self.printerConnected = false
                self.connectButton.title = NSLocalizedString("Connect", comment: "")
            } else {
                self.printerConnected = true
                self.connectButton.title = NSLocalizedString("Disconnect", comment: "")
            }
            // Only enable button if we are sure about connection state
            self.connectButton.isEnabled = !assumption
        }
    }
    fileprivate func connectToServer() {
        let defaultPrinter = printerManager!.getDefaultPrinter()! as Printer
        octoPrintClient.connectToServer(printer : defaultPrinter)
        print(defaultPrinter.getStreamPath())
    }
    func notificationAboutToConnectToServer() {
        //print("*************")
    }
    
    func printerStateUpdated(event: CurrentStateEvent) {
        if let closed = event.closedOrError {
            updateConnectButton(printerConnected: !closed, assumption: false)
        }
        updatePrinterStatusView(printerStatus: event.state ?? "Not Populated" ,extruderTemp: event.tool0TempActual ?? 0.0,bedTemp: event.bedTempActual ?? 0.0)
        
    }
    
    func handleConnectionError(error: Error?, response: HTTPURLResponse) {
        print("ERROR - handleConnectionError")
        self.serverConnected = false
    }
    
    func websocketConnected() {
        print("WS Connected")
        self.serverConnected = true
    }
    
    func websocketConnectionFailed(error: Error) {
        print("ERROR - websocketConnectionFailed")
        self.serverConnected = false
    }
    
    @IBAction func toggleConnection(_ sender: NSButton) {
        if printerConnected! {
            self.octoPrintClient.disconnectFromPrinter { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                if requested {
                    // add stuff
                }
                
            }
        }else{
            self.octoPrintClient.connectToPrinter{ (requested: Bool, error: Error?, response: HTTPURLResponse) in
                if requested {
                    // add stuff
                }
                
            }
        }
    }
    
    
}

