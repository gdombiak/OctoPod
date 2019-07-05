import WatchKit
import Foundation


class PanelInterfaceController: WKInterfaceController, PrinterManagerDelegate, PanelManagerDelegate {

    @IBOutlet weak var errorLabel: WKInterfaceLabel!
    @IBOutlet weak var printerStateLabel: WKInterfaceLabel!
    @IBOutlet weak var completionLabel: WKInterfaceLabel!
    @IBOutlet weak var printTimeLeftLabel: WKInterfaceLabel!
    
    @IBOutlet weak var bedTempLabel: WKInterfaceLabel!
    @IBOutlet weak var tool0TempLabel: WKInterfaceLabel!
    @IBOutlet weak var tool1Group: WKInterfaceGroup!
    @IBOutlet weak var tool1TempImage: WKInterfaceImage!
    @IBOutlet weak var tool1TempLabel: WKInterfaceLabel!
    @IBOutlet weak var chamberImage: WKInterfaceImage!
    @IBOutlet weak var chamberTempLabel: WKInterfaceLabel!

    @IBOutlet weak var buttonsSeparator: WKInterfaceSeparator!
    @IBOutlet weak var buttonsGroup: WKInterfaceGroup!
    @IBOutlet weak var resumeButton: WKInterfaceButton!
    @IBOutlet weak var pauseButton: WKInterfaceButton!
    @IBOutlet weak var cancelButton: WKInterfaceButton!
    @IBOutlet weak var refreshButton: WKInterfaceButton!
    
    // Keep track of the printer being displayed
    var printerURL: String?
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Configure interface objects here.
        self.hideJobButtons()
        self.tool1Group.setHidden(true)
        self.tool1TempImage.setHidden(true)
        self.tool1TempLabel.setHidden(true)
        self.chamberImage.setHidden(true)
        self.chamberTempLabel.setHidden(true)

        // If Watch App just started and we have printers (because they were stored in the file)
        // then make this page the default one
        if !PrinterManager.instance.printers.isEmpty {
            self.becomeCurrentPage()
        }
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
        // Listen to changes to list of printers
        PrinterManager.instance.delegates.append(self)
        // Listen to changes to panel information
        PanelManager.instance.delegates.append(self)

        if let printer = PrinterManager.instance.defaultPrinter() {
            // Update title of window with printer name
            let currentPrinterName = PrinterManager.instance.name(printer: printer)
            self.setTitle(currentPrinterName)
            
            // Check if we need to clear fields information
            let url = PrinterManager.instance.hostname(printer: printer)
            if printerURL != url {
                clearFields()
            }
            // Remember printer being displayed
            printerURL = url
            
            // Display last known panel information
            if let printerName = PanelManager.instance.printerName, let panelInfo = PanelManager.instance.panelInfo, let lastRefresh = PanelManager.instance.lastRefresh, currentPrinterName == printerName {
                panelInfoUpdate(printerName: printerName, panelInfo: panelInfo)

                // Check if information is stale
                let diff = Int(Date().timeIntervalSince1970 - lastRefresh.timeIntervalSince1970)
                if diff > 10 {
                    // Panel information is older than 10 seconds so refresh it
                    renderPrinter()
                }
            } else {
                // Refresh panel information
                renderPrinter()
            }
        } else {
            // Clear any fields information
            clearFields()
            // Remember printer being displayed
            printerURL = nil
        }        
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()

        // Stop listening to changes to list of printers
        PrinterManager.instance.remove(printerManagerDelegate: self)
        // Stop listening to changes to panel information
        PanelManager.instance.remove(panelManagerDelegate: self)
    }

    @IBAction func resumeJob() {
        OctoPrintClient.instance.resumeCurrentJob(callback: { (requested: Bool, error: String?) in
            if !requested {
                if let error = error {
                    NSLog("Failed to request to resume job. Error: \(error)")
                }
                let title = NSLocalizedString("Job", comment: "")
                let message = NSLocalizedString("Notify failed resume job", comment: "")
                UIUtils.showAlert(presenter: self, title: title, message: message, done: nil)
            } else {
                // Wait 1 second and refresh UI
                DispatchQueue.global().asyncAfter(deadline: .now() + 1, execute: {
                    self.renderPrinter()
                })
            }
        })
    }
    
    @IBAction func pauseJob() {
        let confirmText = NSLocalizedString("Do you want to pause the job?", comment: "")
        let yes = {
            OctoPrintClient.instance.pauseCurrentJob(callback: { (requested: Bool, error: String?) in
                if !requested {
                    if let error = error {
                        NSLog("Failed to request to pause job. Error: \(error)")
                    }
                    let title = NSLocalizedString("Job", comment: "")
                    let message = NSLocalizedString("Notify failed pause job", comment: "")
                    UIUtils.showAlert(presenter: self, title: title, message: message, done: nil)
                } else {
                    // Wait 1 second and refresh UI
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1, execute: {
                        self.renderPrinter()
                    })
                }
            })
        }
        UIUtils.showConfirm(presenter: self, message: confirmText, yes: yes, no: nil)
    }
    
    @IBAction func cancelJob() {
        let confirmText = NSLocalizedString("Do you want to cancel job?", comment: "")
        let yes = {
            OctoPrintClient.instance.cancelCurrentJob(callback: { (requested: Bool, error: String?) in
                if !requested {
                    if let error = error {
                        NSLog("Failed to request to cancel job. Error: \(error)")
                    }
                    let title = NSLocalizedString("Job", comment: "")
                    let message = NSLocalizedString("Notify failed cancel job", comment: "")
                    UIUtils.showAlert(presenter: self, title: title, message: message, done: nil)
                } else {
                    // Wait 1 second and refresh UI
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1, execute: {
                        self.renderPrinter()
                    })
                }
            })
        }
        UIUtils.showConfirm(presenter: self, message: confirmText, yes: yes, no: nil)
    }
    
    @IBAction func refresh() {
        renderPrinter()
    }
    
    // MARK: - PrinterManagerDelegate
    
    func printersChanged() {
        // Do nothing
    }
    
    func defaultPrinterChanged(newDefault: [String : Any]?) {
        // Clean up values from previous printer
        DispatchQueue.main.async {
            // Update title of window with printer name
            if let printer = newDefault {
                self.setTitle(PrinterManager.instance.name(printer: printer))
                // Remember printer being displayed
                self.printerURL = PrinterManager.instance.hostname(printer: printer)
            } else {
                // Remember printer being displayed
                self.printerURL = nil
            }
            self.clearFields()
        }
    }

    // Notification that an image has been received from a received file
    // If image is nil then that means that there was an error reading
    // the file to get the image
    func imageReceived(image: UIImage?, cameraId: String) {
        // Do nothing
    }
    
    // MARK: - PanelManagerDelegate
    
    // Notification that new panel information has been received
    func panelInfoUpdate(printerName: String, panelInfo: [String : Any]) {
        DispatchQueue.main.async {
            if let error = panelInfo["error"] as? String {
                self.errorLabel.setText(error)
                self.errorLabel.setHidden(false)
                // Clean up rest of fields
                self.printerStateLabel.setText(nil)
                self.completionLabel.setText(nil)
                self.printTimeLeftLabel.setText(nil)
                self.bedTempLabel.setText("    ")
                self.tool0TempLabel.setText("     ")
                self.tool1Group.setHidden(true)
                self.tool1TempImage.setHidden(true)
                self.tool1TempLabel.setHidden(true)
                self.chamberImage.setHidden(true)
                self.chamberTempLabel.setHidden(true)
                self.hideJobButtons()
            } else {
                // Hide error message
                self.errorLabel.setHidden(true)
                
                // Update UI fields
                if let state = panelInfo["state"] as? String {
                    self.printerStateLabel.setText(state.starts(with: "Offline (Error:") ? "Offline" : state)
                }
                if let completion = panelInfo["completion"] as? Double {
                    let progressText = String(format: "%.1f", completion)
                    self.completionLabel.setText("\(progressText)%")
                }
                if let printTimeLeft = panelInfo["printTimeLeft"] as? Int {
                    self.printTimeLeftLabel.setText(self.secondsToTimeLeft(seconds: printTimeLeft))
                } else if let printTimeLeft = panelInfo["printTimeLeft"] as? String {
                    self.printTimeLeftLabel.setText(printTimeLeft)
                }
                if let bedTemp = panelInfo["bedTemp"] as? Double {
                    let temp = String(format: "%.1f", bedTemp)
                    self.bedTempLabel.setText("\(temp) C")
                }
                if let tool0Temp = panelInfo["tool0Temp"] as? Double {
                    let temp = String(format: "%.1f", tool0Temp)
                    self.tool0TempLabel.setText("\(temp) C")
                    // Check if there is a second extruder and show group and temp
                    var showSecondRow = false
                    if let tool1Temp = panelInfo["tool1Temp"] as? Double {
                        self.tool1TempLabel.setText("\(String(format: "%.1f", tool1Temp)) C")
                        self.tool1TempImage.setHidden(false)
                        self.tool1TempLabel.setHidden(false)
                        showSecondRow = true
                    } else {
                        self.tool1TempImage.setHidden(true)
                        self.tool1TempLabel.setHidden(true)
                    }
                    // Check if there is a heated chamber and show group and temp
                    if let chamberTemp = panelInfo["chamberTemp"] as? Double {
                        self.chamberTempLabel.setText("\(String(format: "%.1f", chamberTemp)) C")
                        self.chamberImage.setHidden(false)
                        self.chamberTempLabel.setHidden(false)
                        showSecondRow = true
                    } else {
                        self.chamberImage.setHidden(true)
                        self.chamberTempLabel.setHidden(true)
                    }
                    self.tool1Group.setHidden(!showSecondRow)
                }
                if let printer = panelInfo["printer"] as? String {
                    self.buttonsSeparator.setHidden(false)
                    self.buttonsGroup.setHidden(false)
                    if printer == "printing" {
                        self.resumeButton.setHidden(true)
                        self.pauseButton.setHidden(false)
                        self.cancelButton.setHidden(false)
                    } else if printer == "paused" {
                        // Printer is paused
                        self.resumeButton.setHidden(false)
                        self.pauseButton.setHidden(true)
                        self.cancelButton.setHidden(false)
                    } else {
                        // Not printing and not paused and no progress info then clean up text
                        if panelInfo["completion"] == nil {
                            self.completionLabel.setText(nil)
                        }
                        // Not printing and not paused and no printTimeLeft info then clean up text
                        if panelInfo["printTimeLeft"] == nil {
                            self.printTimeLeftLabel.setText(nil)
                        }
                        if printer == "operational" {
                            self.hideJobButtons()
                        }
                    }
                } else {
                    self.hideJobButtons()
                }
            }
        }
    }

    // Notification that we need to update complications. Originated from iOS App
    func updateComplications(printerName: String, printerState: String) {
        // Do nothing
    }
    
    // MARK: - Private functions
    
    fileprivate func renderPrinter() {
        // Disable refresh button to indicate we are "refreshing"
        self.refreshButton.setEnabled(false)
        PanelManager.instance.refresh {
            DispatchQueue.main.async {
                // Done refreshing so enable button again
                self.refreshButton.setEnabled(true)
            }
        }
    }
    
    fileprivate func hideJobButtons() {
        // Hide all buttons if printer is operational
        self.buttonsSeparator.setHidden(true)
        self.buttonsGroup.setHidden(true)
        self.resumeButton.setHidden(true)
        self.pauseButton.setHidden(true)
        self.cancelButton.setHidden(true)
    }
    
    fileprivate func clearFields() {
        self.printerStateLabel.setText(nil)
        self.completionLabel.setText(nil)
        self.printTimeLeftLabel.setText(nil)
        self.bedTempLabel.setText(nil)
        self.tool0TempLabel.setText("     ")  // Put some space so extruder icon looks ok
        self.tool1TempLabel.setText("     ")  // Put some space so extruder icon looks ok
        self.chamberTempLabel.setText("     ")  // Put some space so extruder icon looks ok
    }
    
    fileprivate func secondsToTimeLeft(seconds: Int) -> String {
        if seconds == 0 {
            return ""
        } else if seconds < 0 {
            // Should never happen but an OctoPrint plugin is returning negative values
            // so return 'Unknown' when this happens
            return NSLocalizedString("Unknown", comment: "ETA is Unknown")
        }
        let duration = TimeInterval(seconds)
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.includesApproximationPhrase = true
        // If more than a day and Apple Watch is 38mm then do not display minutes
        if seconds > 86400 && WKInterfaceDevice.current().screenBounds.size.width == 136 {
            formatter.allowedUnits = [ .day, .hour]
        } else {
            formatter.allowedUnits = [ .day, .hour, .minute ]
        }
        return formatter.string(from: duration)!
    }
}
