import UIKit

class EnclosureViewController : ThemedDynamicUITableViewController, SubpanelViewController, OctoPrintSettingsDelegate, OctoPrintPluginsDelegate {
    
    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()

    private var outputs: Array<EnclosureOutputData> = []

    override func viewDidLoad() {
        super.viewDidLoad()
    
        // Some bug in XCode Storyboards is not translating text of refresh control so let's do it manually
        self.refreshControl?.attributedTitle = NSAttributedString(string: NSLocalizedString("Pull down to refresh", comment: ""))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Fetch and render Enclosure outputs
        refreshOutputs(done: nil)

        // Listen to changes to OctoPrint Plugin messages
        octoprintClient.octoPrintPluginsDelegates.append(self)
        // Listen to changes to OctoPrint Settings
        octoprintClient.octoPrintSettingsDelegates.append(self)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Stop listening to changes to OctoPrint Plugin messages
        octoprintClient.remove(octoPrintPluginsDelegate: self)
        // Stop listening to changes to OctoPrint Settings
        octoprintClient.remove(octoPrintSettingsDelegate: self)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return outputs.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Enclosure"  // No need to translate name of plugin
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let output = outputs[indexPath.row]
        if output.type == "regular" {
            let cell = tableView.dequeueReusableCell(withIdentifier: "gpio_cell", for: indexPath) as! EnclosureGPIOViewCell

            // Configure the cell
            cell.parentVC = self
            cell.titleLabel.text = output.label
            cell.titleLabel.textColor = Theme.currentTheme().textColor()
            cell.setPowerState(isPowerOn: output.status)

            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "pwm_cell", for: indexPath) as! EnclosurePWMViewCell

            // Configure the cell
            cell.parentVC = self
            cell.titleLabel.text = output.label
            let theme = Theme.currentTheme()
            let textColor = theme.textColor()
            cell.titleLabel.textColor = textColor
            cell.pwmField.backgroundColor = theme.backgroundColor()
            cell.pwmField.textColor = textColor
            cell.pwmField.isEnabled = !appConfiguration.appLocked() // Enable field only if app is not locked

            return cell
        }
    }
    
    // MARK: - Table view operations
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 36
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 1
    }

    // MARK: - SubpanelViewController

    func printerSelectedChanged() {
        // Only refresh UI if view controller is being shown
        DispatchQueue.main.async {
            if let _ = self.parent {
                // Fetch and render Enclosure outputs
                self.refreshOutputs(done: nil)
            }
        }
    }
    
    func currentStateUpdated(event: CurrentStateEvent) {
        // Do nothing
    }
    
    func position() -> Int {
        return 45
    }

    // MARK: - OctoPrintSettingsDelegate
    
    func enclosureOutputsChanged() {
        DispatchQueue.main.async {
            if let _ = self.parent {
                // Fetch and render Enclosure outputs
                self.refreshOutputs(done: nil)
            }
        }
    }

    // MARK: - OctoPrintPluginsDelegate
    
    func pluginMessage(plugin: String, data: NSDictionary) {
        if plugin == Plugins.ENCLOSURE {
            if let _ = data["rpi_output_regular"] {
                // Refresh status of outputs. Doing a new fetch is not the most
                // efficient way to do this but this is an infrequent operation
                // so it is good enough and we can reuse some code
                refreshOutputsStatus(done: nil)
            }
        }
    }

    // MARK: - Notifications from Cells
    
    func powerPressed(cell: EnclosureGPIOViewCell) {
        if let on = cell.isPowerOn, let printer = printerManager.getDefaultPrinter() {
            if let indexPath = self.tableView.indexPath(for: cell) {
                let output = self.outputs[indexPath.row]

                // Donate Siri Intentions
                IntentsDonations.donateEnclosureTurnOn(printer: printer, switchLabel: output.label)
                IntentsDonations.donateEnclosureTurnOff(printer: printer, switchLabel: output.label)

                let changePower = {
                    let generator = UINotificationFeedbackGenerator()
                    generator.prepare()
                    self.octoprintClient.changeEnclosureGPIO(index_id: output.index, status: !on) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                        if requested {
                           DispatchQueue.main.async {
                                generator.notificationOccurred(.success)
                            }
                            // Update in memory status
                            output.status = !on
                            // Refresh row
                            DispatchQueue.main.async {
                                self.tableView.reloadRows(at: [indexPath], with: .automatic)
                            }
                        } else {
                            // Handle error
                            let message = !on ? NSLocalizedString("Failed to request to turn power on", comment: "") : NSLocalizedString("Failed to request to turn power off", comment: "")
                            self.showAlert(NSLocalizedString("Warning", comment: ""), message: message)
                        }
                    }
                }
                if on {
                    showConfirm(message: String(format: NSLocalizedString("Confirm turn off", comment: ""), output.label), yes: { (UIAlertAction) -> Void in
                        changePower()
                    }, no: { (UIAlertAction) -> Void in
                        // Do nothing
                    })
                } else {
                    changePower()
                }
            }
        }
    }
    
    func pwmChanged(cell: EnclosurePWMViewCell, dutyCycle: Int) {
        if let indexPath = self.tableView.indexPath(for: cell) {
            let output = self.outputs[indexPath.row]
            let changePower = {
                let generator = UINotificationFeedbackGenerator()
                generator.prepare()
                self.octoprintClient.changeEnclosurePWM(index_id: output.index, dutyCycle: dutyCycle) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                    if requested {
                        DispatchQueue.main.async {
                            generator.notificationOccurred(.success)
                            // Clean up value of cell
                            cell.pwmField.text = nil
                            // Refresh row
                            self.tableView.reloadRows(at: [indexPath], with: .automatic)
                        }
                    } else {
                        // Handle error
                        let message = dutyCycle > 0 ? NSLocalizedString("Failed to request to turn power on", comment: "") : NSLocalizedString("Failed to request to turn power off", comment: "")
                        self.showAlert(NSLocalizedString("Warning", comment: ""), message: message)
                    }
                }
            }
            if dutyCycle <= 0 {
                showConfirm(message: String(format: NSLocalizedString("Confirm turn off", comment: ""), output.label), yes: { (UIAlertAction) -> Void in
                    changePower()
                }, no: { (UIAlertAction) -> Void in
                    // Do nothing
                })
            } else {
                changePower()
            }
        }
    }
    
    // MARK: - Refresh
    
    @IBAction func refreshControls(_ sender: UIRefreshControl) {
        // Render outputs status
        refreshOutputsStatus(done: {
            DispatchQueue.main.async {
                sender.endRefreshing()
            }
        })
    }
    
    // MARK: - Private functions
    
    fileprivate func refreshOutputs(done: (() -> Void)?) {
        if let printer = printerManager.getDefaultPrinter() {
            // Wrap outputs with a wrapper that holds status
            var newOutputs = Array<EnclosureOutputData>()
            for output in printer.getEnclosureOutputs() {
                newOutputs.append(EnclosureOutputData(output: output))
            }
            // Sort array by label for convenience/consistency
            newOutputs.sort {
                return $0.label < $1.label
            }
            // Store new outputs
            self.outputs = newOutputs
            // Refresh table with new outputs
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
            refreshOutputsStatus(done: done)
        } else {
            // Execute done block when done
            done?()
        }
    }

    fileprivate func refreshOutputsStatus(done: (() -> Void)?) {
        // Fetch current status for GPIO outputs
        for output in self.outputs {
            if output.type == "regular" {
                let outputIndex = output.index
                self.octoprintClient.getEnclosureGPIOStatus(index_id: output.index) { (value: Bool?, error: Error?, response: HTTPURLResponse) in
                    if let value = value {
                        for (index, outputToUpdate) in self.outputs.enumerated() {
                            if outputIndex == outputToUpdate.index {
                                // Update status in wrapper
                                outputToUpdate.status = value
                                // Refresh only row of updated status
                                DispatchQueue.main.async {
                                    self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
                                }
                            }
                        }
                    }
                }
            }
        }
        // Execute done block when done
        done?()
    }
    
    fileprivate func showAlert(_ title: String, message: String) {
        UIUtils.showAlert(presenter: self, title: title, message: message, done: nil)
    }

    fileprivate func showConfirm(message: String, yes: @escaping (UIAlertAction) -> Void, no: @escaping (UIAlertAction) -> Void) {
        UIUtils.showConfirm(presenter: self, message: message, yes: yes, no: no)
    }
}

private class EnclosureOutputData {
    var type: String
    var index: Int16
    var label: String
    var status: Bool
    
    init(output: EnclosureOutput) {
        self.type = output.type
        self.index = output.index_id
        self.label = output.label
        self.status = false
    }
}

