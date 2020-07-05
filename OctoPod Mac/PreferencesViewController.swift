//
//  PreferencesViewController.swift
//  OctoPod Mac
//
//  Created by Arijit Banerjee on 7/2/20.
//  Copyright © 2020 Gaston Dombiak. All rights reserved.
//

import Foundation
import Cocoa
import CoreData

class PreferencesViewController: NSViewController{
    
    @IBOutlet var printerNameValue : NSTextField!
    
    @IBOutlet weak var printerHostNameValue: NSTextField!
    @IBOutlet weak var octoPrintAPITokenValue: NSTextField!
    @IBOutlet weak var ignoreSSLValue: NSButton!
    @IBOutlet weak var updatePrinterButton: NSButton!
    weak var delegate: PreferencesDelegate?
    
    let printerManager: PrinterManager = { return (NSApp.delegate as! AppDelegate).printerManager! }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let defaultPrinter = printerManager.getDefaultPrinter()
        {
            printerHostNameValue.stringValue = defaultPrinter.hostname
            octoPrintAPITokenValue.stringValue = defaultPrinter.apiKey
            printerNameValue.stringValue = defaultPrinter.name
            ignoreSSLValue.state = defaultPrinter.ignoreSSLCertValidationError ? NSControl.StateValue.on : NSControl.StateValue.off
        }
        
        
    }
    
    private func validateInput() -> Bool{
        let apiKey = octoPrintAPITokenValue.stringValue
        let hostname = printerHostNameValue.stringValue
        let printerName = printerNameValue.stringValue
        if(apiKey.isEmpty || hostname.isEmpty || printerName.isEmpty){
            return false
        }
        if (!UIUtils.isValidURL(urlString: hostname)){
            return false
        }
        return true
    }
    
    
    @IBAction func addUpdatePrinter(_ sender: NSButton) {
        let apiKey = octoPrintAPITokenValue.stringValue
        let hostname = printerHostNameValue.stringValue
        let printerName = printerNameValue.stringValue
        if let defaultPrinter = printerManager.getDefaultPrinter()
            //existing printer
        {
            defaultPrinter.apiKey = apiKey
            defaultPrinter.hostname = hostname
            defaultPrinter.name = printerName
            defaultPrinter.defaultPrinter = true
            defaultPrinter.ignoreSSLCertValidationError = ignoreSSLValue.state == .on ? true: false
            printerManager.updatePrinter(defaultPrinter)
            if let listener = delegate {
                listener.printerUpdated(printer: defaultPrinter)
            }
            UIUtils.showAlert(title: "Info", message: "Printer updated.")
            
        }else{
            //new printer
            let success = printerManager.addPrinter(name: printerName, hostname: hostname, apiKey: apiKey, username: nil, password: nil, position: 0, iCloudUpdate: false)
            if(success){
                if let defaultPrinter = printerManager.getDefaultPrinter(){
                    defaultPrinter.ignoreSSLCertValidationError  = ignoreSSLValue.state == .on ? true: false
                    printerManager.updatePrinter(defaultPrinter)
                    if let listener = delegate {
                        listener.printerAdded(printer: defaultPrinter)
                    }
                    UIUtils.showAlert(title: "Info", message: "Printer added.")
                }
                else{
                    UIUtils.showAlert(title: "Error", message: "Cannot add printer")
                }
            }
            
        }
        
    }
    
    @IBAction func resetPrinters(_ sender: Any) {
        let confirmation = UIUtils.showConfirm(title: "Are you sure?", message: "This will delete all printers registered to OctoPod.")
        
        if(confirmation){
            if let defaultPrinter = printerManager.getDefaultPrinter(){
                let newObjectContext = printerManager.newPrivateContext()
                printerManager.deleteAllPrinters(context: newObjectContext)
                
                if let listener = delegate {
                    listener.printerDeleted(printer: defaultPrinter)
                }
                printerHostNameValue.stringValue = ""
                octoPrintAPITokenValue.stringValue = ""
                printerNameValue.stringValue = ""
                ignoreSSLValue.state = NSControl.StateValue.off
                
                UIUtils.showAlert(title: "Done", message: "All Printers Deleted")
            }
            
        }
        
    }
    
    @IBAction func hostURLChanged(_ sender: Any) {
        let inputURL = printerHostNameValue.stringValue
        // Add http protocol to URL if no protocol was specified
        if !inputURL.lowercased().starts(with: "http") {
            printerHostNameValue.stringValue = "http://" + inputURL
        }
            updatePrinterButton.isEnabled = validateInput()
        
    }
    
    @IBAction func printerNameChanged(_ sender: Any) {
        updatePrinterButton.isEnabled = validateInput()
    }
    
    @IBAction func apiTokenChanged(_ sender: Any) {
        updatePrinterButton.isEnabled = validateInput()
    }
}
