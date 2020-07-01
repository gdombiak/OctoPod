//
//  ViewController.swift
//  OctoPod Mac
//
//  Created by Arijit Banerjee on 6/27/20.
//  Copyright © 2020 Gaston Dombiak. All rights reserved.
//

import Cocoa
import CoreData

class ViewController: NSViewController, OctoPrintClientDelegate {
    
    @IBOutlet weak var cameraImageView: CameraImageView!
    @IBOutlet weak var connectButton: NSButton!
    
    @IBOutlet weak var printerStatusLabel: NSTextField!
    
    @IBOutlet weak var printerStatusValue: NSTextField!
    
    @IBOutlet weak var actualExtruderTempValue: NSTextField!
    @IBOutlet weak var targetExtruderTempValue: NSTextField!
    @IBOutlet weak var actualBedTempValue: NSTextField!
    @IBOutlet weak var targetBedTempValue: NSTextField!
    
    @IBOutlet weak var progressPrintTimeValue: NSTextField!
    @IBOutlet weak var progressPrintTimeLeftValue: NSTextField!
    @IBOutlet weak var progressPrintCompletionValue: NSTextField!
    
    @IBOutlet weak var progressPercentValue: NSTextField!
    @IBOutlet weak var progressBar: NSProgressIndicator!
    
    @IBOutlet weak var cancelButton: NSButton!
    @IBOutlet weak var pauseResumeButton: NSButton!
    
    private var serverConnected = false
    private var printerConnected: Bool?
    private var isPrinting : Bool!
    private var isPaused : Bool!
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
        
        streamingController = MjpegStreamingController(imageView: cameraImageView)
        streamingController?.play(url: URL(string:"https://arijit.org/webcam/?action=stream")!)
    }
    
    func updatePrinterStatusView(printerStatus:String?,actualExtruderTemp:Double?,targetExtruderTemp:Double?,actualBedTemp:Double?,targetBedTemp:Double?,progressPrintTime:Int?,progressPrintTimeLeft:Int?, progressCompletion:Double?){
        
        printerStatusValue.stringValue = printerStatus ?? "Unknown"
        actualBedTempValue.doubleValue = actualBedTemp ?? actualBedTempValue.doubleValue
        targetBedTempValue.doubleValue = targetBedTemp ??  targetBedTempValue.doubleValue
        actualExtruderTempValue.doubleValue = actualExtruderTemp ?? actualExtruderTempValue.doubleValue
        targetExtruderTempValue.doubleValue = targetExtruderTemp ?? targetExtruderTempValue.doubleValue
        progressBar.doubleValue = progressCompletion ?? progressBar.doubleValue
        progressPercentValue.doubleValue = progressCompletion?.round(to: 1) ?? progressPercentValue.doubleValue
        let progressPrintTimeLeftDouble = Double(progressPrintTimeLeft ?? 0)
        progressPrintTimeValue.stringValue = UIUtils.secondsToPrintTime(seconds: progressPrintTime ?? 0)
        progressPrintTimeLeftValue.stringValue = UIUtils.secondsToEstimatedPrintTime(seconds: progressPrintTimeLeftDouble)
        progressPrintCompletionValue.stringValue = UIUtils.secondsToETA(seconds: progressPrintTimeLeft ?? 0)
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
        
    }
    func notificationAboutToConnectToServer() {
        //print("*************")
    }
    
    func printerStateUpdated(event: CurrentStateEvent) {
        DispatchQueue.main.async {
            //Do UI Code here.
            if let closed = event.closedOrError {
                self.updateConnectButton(printerConnected: !closed, assumption: false)
                
            }
            if let isPrinting = event.printing {
                self.isPrinting = event.printing
                DispatchQueue.main.async {
                    if(isPrinting){
                        self.cancelButton.isEnabled = true
                        self.pauseResumeButton.isEnabled = true
                        self.cancelButton.contentTintColor = .systemRed
                        self.pauseResumeButton.contentTintColor = .systemYellow
                        self.pauseResumeButton.title = "Pause"
                    }else{
                        self.cancelButton.isEnabled = false
                        self.pauseResumeButton.isEnabled = false
                        self.cancelButton.contentTintColor = .systemGray
                        self.pauseResumeButton.contentTintColor = .systemGray
                    }
                }
            }
            if let isPaused = event.paused {
                self.isPaused = event.paused
                DispatchQueue.main.async {
                    if(isPaused){
                        self.pauseResumeButton.isEnabled = true
                        self.cancelButton.isEnabled = true
                        self.cancelButton.contentTintColor = .systemRed
                        self.pauseResumeButton.contentTintColor = .systemGreen
                        self.pauseResumeButton.title = "Resume"
                    }
                }
            }
            if let isPausing = event.pausing {
                DispatchQueue.main.async {
                    if(isPausing){
                        self.pauseResumeButton.isEnabled = false
                        self.cancelButton.isEnabled = false
                        self.cancelButton.contentTintColor = .systemGray
                        self.pauseResumeButton.contentTintColor = .systemGray
                        self.pauseResumeButton.title = "Resume"
                    }
                }
            }
            
            if let isCancelling = event.cancelling {
                DispatchQueue.main.async {
                    if(isCancelling){
                        self.pauseResumeButton.isEnabled = false
                        self.cancelButton.isEnabled = false
                        self.cancelButton.contentTintColor = .systemGray
                        self.pauseResumeButton.contentTintColor = .systemGray
                        self.pauseResumeButton.title = "Pause"
                    }
                    
                }
            }
            
            self.updatePrinterStatusView(
                printerStatus: event.state ,
                actualExtruderTemp: event.tool0TempActual ,
                targetExtruderTemp: event.tool0TempTarget ,
                actualBedTemp: event.bedTempActual ,
                targetBedTemp: event.bedTempTarget,
                progressPrintTime: event.progressPrintTime,
                progressPrintTimeLeft: event.progressPrintTimeLeft,
                progressCompletion: event.progressCompletion
            )
        }
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
        self.octoPrintClient.disconnectFromServer()
        self.updateConnectButton(printerConnected: false,assumption: false)
        self.serverConnected = false
        
    }
    
    @IBAction func toggleConnection(_ sender: NSButton) {
        if printerConnected! {
            self.octoPrintClient.disconnectFromPrinter { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                if requested {
                    DispatchQueue.main.async {
                        self.actualBedTempValue.doubleValue = 0.0
                        self.actualExtruderTempValue.doubleValue = 0.0
                        self.targetExtruderTempValue.doubleValue = 0.0
                        self.targetBedTempValue.doubleValue = 0.0
                    }
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
    
    @IBAction func togglePauseResume(_ sender: Any) {
        pauseResumeButton.isEnabled = false
        if(self.isPaused){
            self.octoPrintClient.resumeCurrentJob { (request:Bool, error: Error?, response:HTTPURLResponse) in
                print("Resumed")
            }
        }
        else if(self.isPrinting){
            self.octoPrintClient.pauseCurrentJob { (request:Bool, error: Error?, response:HTTPURLResponse) in
                print("Paused")
            }
        }
        
    }
    
    @IBAction func cancelPrint(_ sender: Any) {
        cancelButton.isEnabled = false
        if(self.isPrinting || self.isPaused){
            self.octoPrintClient.cancelCurrentJob { (request:Bool, error: Error?, response:HTTPURLResponse) in
                print("Cancelled")
            }
        }
    }
}

