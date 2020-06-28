//
//  OctoPrintClient.swift
//  OctoPod Mac
//
//  Created by Arijit Banerjee on 6/27/20.
//  Copyright © 2020 Gaston Dombiak. All rights reserved.
//

import Foundation
class OctoPrintClient1{
// Remember last CurrentStateEvent that was reported from OctoPrint (via websockets)
    var lastKnownState: CurrentStateEvent?
    var octoPrintVersion: String?
    var octoPrintRESTClient: OctoPrintRESTClient!
    var webSocketClient: WebSocketClient?
    var printerManager: PrinterManager!
    
    init(printerManager: PrinterManager) {
           self.printerManager = printerManager
           self.octoPrintRESTClient = OctoPrintRESTClient()
           #if os(iOS)
               // Configure REST client to show network activity in iOS app when making requests
               self.octoPrintRESTClient.preRequest = {
                   DispatchQueue.main.async(execute: { () -> Void in UIApplication.shared.isNetworkActivityIndicatorVisible = true })
               }
               self.octoPrintRESTClient.postRequest = {
                   DispatchQueue.main.async(execute: { () -> Void in UIApplication.shared.isNetworkActivityIndicatorVisible = false })
               }
           #endif
       }
    
    func connectToServer(printer: Printer) {
        // Clean up any known printer state
        lastKnownState = nil
        
        // Create and keep httpClient while default printer does not change
        octoPrintRESTClient.connectToServer(serverURL: printer.hostname, apiKey: printer.apiKey, username: printer.username, password: printer.password)
        
        if webSocketClient?.isConnected(printer: printer) == true {
            // Do nothing since we are already connected to the default printer
            return
        }
        
        // We need to rediscover the version of OctoPrint so clean up old values
        octoPrintVersion = nil
        
        // Close any previous connection
        webSocketClient?.closeConnection()
        
        webSocketClient = WebSocketClient(printer: printer)
        
        // It might take some time for Octoprint to report current state via websockets so ask info via HTTP
        printerState { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
            if !self.isConnectionError(error: error, response: response) {
                // There were no errors so process
                var event: CurrentStateEvent?
                if let json = result as? NSDictionary {
                    event = CurrentStateEvent()
                    if let temp = json["temperature"] as? NSDictionary {
                        event!.parseTemps(temp: temp, sharedNozzle: printer.sharedNozzle)
                    }
                    if let state = json["state"] as? NSDictionary {
                        event!.parseState(state: state)
                    }
                } else if response.statusCode == 409 {
                    // Printer is not operational
                    event = CurrentStateEvent()
                    event!.closedOrError = true
                    event!.state = "Offline"
                }
                if let _ = event {
                    // Notify that we received new status information from OctoPrint
                    self.currentStateUpdated(event: event!)
                }
            } else {
                // Notify of connection error
                
            }
        }
        
        // Verify that last known settings are still current
      
        
        // Discover OctoPrint version
        octoPrintRESTClient.versionInformation { (result: NSObject?, error: Error?, response: HTTPURLResponse) in
            if let json = result as? NSDictionary {
                if let server = json["server"] as? String {
                    self.octoPrintVersion = server
                }
            }
        }
    }
    
    func printerState(callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.printerState(callback: callback)
    }
    
    
    fileprivate func isConnectionError(error: Error?, response: HTTPURLResponse) -> Bool {
        if let _ = error as NSError? {
            return true
        } else if response.statusCode == 403 {
            return true
        } else {
            // Return that there were no errors
            return false
        }
    }
    
    func currentStateUpdated(event: CurrentStateEvent) {
        // Track event as last known state. Will be reset when changing printers or on app cold startup
        lastKnownState = event
        // Notify the terminal that OctoPrint and/or Printer state has changed
    
        // Track temp history
        if event.bedTempActual != nil || event.tool0TempActual != nil || event.tool1TempActual != nil || event.tool2TempActual != nil || event.tool3TempActual != nil || event.tool4TempActual != nil {
            var temp = TempHistory.Temp()
            temp.parseTemps(event: event)
           
        }
        
    }
    func octoPrintSettings(callback: @escaping (NSObject?, Error?, HTTPURLResponse) -> Void) {
        octoPrintRESTClient.octoPrintSettings(callback: callback)
    }
}
