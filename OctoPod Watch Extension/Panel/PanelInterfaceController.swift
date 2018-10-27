import WatchKit
import Foundation


class PanelInterfaceController: WKInterfaceController, PrinterManagerDelegate {

    @IBOutlet weak var errorLabel: WKInterfaceLabel!
    @IBOutlet weak var printerStateLabel: WKInterfaceLabel!
    @IBOutlet weak var completionLabel: WKInterfaceLabel!
    @IBOutlet weak var printTimeLeftLabel: WKInterfaceLabel!
    
    @IBOutlet weak var bedTempLabel: WKInterfaceLabel!
    @IBOutlet weak var tool0TempLabel: WKInterfaceLabel!
    @IBOutlet weak var tool1Group: WKInterfaceGroup!
    @IBOutlet weak var tool1TempLabel: WKInterfaceLabel!
    
    @IBOutlet weak var buttonsSeparator: WKInterfaceSeparator!
    @IBOutlet weak var buttonsGroup: WKInterfaceGroup!
    @IBOutlet weak var resumeButton: WKInterfaceButton!
    @IBOutlet weak var pauseButton: WKInterfaceButton!
    @IBOutlet weak var cancelButton: WKInterfaceButton!
    
    // Keep track of the printer being displayed
    var printerURL: String?
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Configure interface objects here.
        self.hideJobButtons()
        self.tool1Group.setHidden(true)
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
        // Listen to changes to list of printers
        PrinterManager.instance.delegates.append(self)

        if let printer = PrinterManager.instance.defaultPrinter() {
            // Update title of window with printer name
            self.setTitle(PrinterManager.instance.name(printer: printer))
            
            // Check if we need to clear fields information
            let url = PrinterManager.instance.hostname(printer: printer)
            if printerURL != url {
                clearFields()
            }
            // Remember printer being displayed
            printerURL = url

            // Refresh display for selected printer
            renderPrinter()
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
        // Refresh display for selected printer
        renderPrinter()
    }

    // Notification that an image has been received from a received file
    // If image is nil then that means that there was an error reading
    // the file to get the image
    func imageReceived(image: UIImage?, cameraId: String) {
        // Do nothing
    }
    
    // MARK: - Private functions
    
    fileprivate func renderPrinter() {
        OctoPrintClient.instance.currentJobInfo { (reply: [String : Any]) in
            // TODO Display error
            DispatchQueue.main.async {
                if let error = reply["error"] as? String {
                    self.errorLabel.setText(error)
                    self.errorLabel.setHidden(false)
                } else {
                    self.errorLabel.setHidden(true)
                }
                if let state = reply["state"] as? String {
                    self.printerStateLabel.setText(state)
                }
                if let completion = reply["completion"] as? Double {
                    let progressText = String(format: "%.1f", completion)
                    self.completionLabel.setText("\(progressText)%")
                }
                if let printTimeLeft = reply["printTimeLeft"] as? Int {
                    self.printTimeLeftLabel.setText(self.secondsToTimeLeft(seconds: printTimeLeft))
                }
                if let bedTemp = reply["bedTemp"] as? Double {
                    let temp = String(format: "%.1f", bedTemp)
                    self.bedTempLabel.setText("\(temp) C")
                }
                if let tool0Temp = reply["tool0Temp"] as? Double {
                    let temp = String(format: "%.1f", tool0Temp)
                    self.tool0TempLabel.setText("\(temp) C")
                    // Check if there is a second extruder and show group and temp
                    if let tool1Temp = reply["tool1Temp"] as? Double {
                        let temp = String(format: "%.1f", tool1Temp)
                        self.tool1TempLabel.setText("\(temp) C")
                        self.tool1Group.setHidden(false)
                    } else {
                        self.tool1Group.setHidden(true)
                    }
                }
                if let printer = reply["printer"] as? String {
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
                        if reply["completion"] == nil {
                            self.completionLabel.setText(nil)
                        }
                        // Not printing and not paused and no printTimeLeft info then clean up text
                        if reply["printTimeLeft"] == nil {
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
        formatter.unitsStyle = .brief
        formatter.includesApproximationPhrase = true
        formatter.allowedUnits = [ .day, .hour, .minute ]
        return formatter.string(from: duration)!
    }
}
