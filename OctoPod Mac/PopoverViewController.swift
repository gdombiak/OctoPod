//
//  ViewController.swift
//  OctoPod Mac
//
//  Created by Arijit Banerjee on 6/27/20.
//  Copyright © 2020 Gaston Dombiak. All rights reserved.
//

import Cocoa
import CoreData

class PopoverViewController: NSViewController, OctoPrintClientDelegate, PreferencesDelegate, OctoPrintSettingsDelegate {
    
    
    
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
    @IBOutlet weak var extruderTempProgressBar: NSProgressIndicator!
    @IBOutlet weak var bedTempProgressBar: NSProgressIndicator!
    
    @IBOutlet weak var printerNameLabel: NSTextField!
    
    @IBOutlet weak var octoprintWebButton: NSButton!
    
    private var serverConnected = false
    private var printerConnected: Bool?
    private var isPrinting = false
    private var isPaused = false
    var streamingController: MjpegStreamingController?
    
    let printerManager: PrinterManager = { return (NSApp.delegate as! AppDelegate).printerManager! }()
    
    
    
    lazy var octoPrintClient: OctoPrintClient = {
        let octoPrintClient = OctoPrintClient(printerManager: self.printerManager)
        octoPrintClient.delegates.append(self)
        octoPrintClient.octoPrintSettingsDelegates.append(self)
        return octoPrintClient
    }()
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        bedTempProgressBar.doubleValue = 0.0
        extruderTempProgressBar.doubleValue = 0.0
        connectToServer()
    }
    fileprivate func octoPrintCameraAbsoluteUrl(hostname: String, streamUrl: String) -> String {
        if streamUrl.isEmpty {
            // Should never happen but let's be cautious
            return hostname
        }
        if streamUrl.starts(with: "/") {
            // Build absolute URL from relative URL
            return hostname + streamUrl
        }
        // streamURL is an absolute URL so return it
        return streamUrl
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
        progressBar.appearance = NSAppearance(named: .vibrantLight)
        
        bedTempProgressBar.minValue = 10
        bedTempProgressBar.maxValue = targetBedTempValue.doubleValue < 1.0 ? 100.0 : targetBedTempValue.doubleValue
        bedTempProgressBar.doubleValue = actualBedTempValue.doubleValue
        bedTempProgressBar.appearance = NSAppearance(named: .vibrantLight)
        
        extruderTempProgressBar.minValue = 10
        extruderTempProgressBar.maxValue = targetExtruderTempValue.doubleValue < 1.0 ? 250.0 : targetExtruderTempValue.doubleValue
        extruderTempProgressBar.doubleValue = actualExtruderTempValue.doubleValue
        extruderTempProgressBar.appearance = NSAppearance(named: .vibrantLight)
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    
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
        if let defaultPrinter = printerManager.getDefaultPrinter()
        {
            if !self.serverConnected{
                
                octoPrintClient.connectToServer(printer : defaultPrinter)
                connectCamera(printer: defaultPrinter)
                printerNameLabel.stringValue = defaultPrinter.name
                DispatchQueue.main.async {
                self.octoprintWebButton.isEnabled = true
                }
            }
        }else{
            UIUtils.showAlert(title: "No Printer", message: "Please add a printer from OctoPod Preferences")
        }
        
    }
    private func connectCamera(printer:Printer){
        streamingController = MjpegStreamingController(imageView: cameraImageView)
        if  let defaultPrinterStreamURLString = printer.streamUrl{
            let streamUrl = URL(string:octoPrintCameraAbsoluteUrl(hostname:printer.hostname, streamUrl: defaultPrinterStreamURLString))
            streamingController?.play(url: streamUrl!)
            DispatchQueue.main.async {
                self.cameraImageView.isHidden = false
            }
        }
    }
    private func disconnectFromServer(){
        octoPrintClient.disconnectFromServer()
        serverConnected = false
        streamingController?.stop()
        DispatchQueue.main.async {
            self.updatePrinterStatusView(
                printerStatus: "???" ,
                actualExtruderTemp: 0.0 ,
                targetExtruderTemp: 0.0 ,
                actualBedTemp: 0.0 ,
                targetBedTemp: 0.0,
                progressPrintTime: 0,
                progressPrintTimeLeft: 0,
                progressCompletion: 0.0
            )
            self.printerNameLabel.stringValue = ""
            self.cameraImageView.isHidden = true
            self.octoprintWebButton.isEnabled = false
        }
        self.updateConnectButton(printerConnected: false, assumption: true)
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
        }
        if let isPrinting = event.printing {
            self.isPrinting = event.printing!
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
            self.isPaused = event.paused!
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
        DispatchQueue.main.async {
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
        disconnectFromServer()
        self.serverConnected = false
        
    }
    func printerAdded(printer: Printer) {
        print("printer added")
        connectToServer()
    }
    
    func printerDeleted(printer: Printer) {
        print("printer deleted")
        streamingController?.contentURL = URL(string: "")
        streamingController?.stop()
        disconnectFromServer()
    }
    
    func printerUpdated(printer: Printer) {
        print("printer updated")
        disconnectFromServer()
        connectToServer()
    }
    func cameraPathChanged(streamUrl: String) {
        if let defaultPrinter = printerManager.getDefaultPrinter()
        {
            connectCamera(printer: defaultPrinter)
        }
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
    
    @IBAction func openOctoprintWebsite(_ sender: Any) {
        if let defaultPrinter = printerManager.getDefaultPrinter()
        {
            NSWorkspace.shared.open(URL(string: defaultPrinter.hostname)!)
        }
    }
    @IBAction func openPreferences(_ sender: Any) {
        (NSApp.delegate as! AppDelegate).showPreferences()
    }
    
}

