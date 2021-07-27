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
        } else if output.type == "pwm" {
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
            cell.pwmField.text = "\(output.intValue ?? 0)"

            return cell
        } else if output.type == "temp_hum_control" {
            let cell = tableView.dequeueReusableCell(withIdentifier: "temp_hum_control_cell", for: indexPath) as! EnclosureTempControlViewCell

            // Configure the cell
            cell.parentVC = self
            cell.titleLabel.text = output.label
            let theme = Theme.currentTheme()
            let textColor = theme.textColor()
            cell.titleLabel.textColor = textColor
            cell.pwmField.backgroundColor = theme.backgroundColor()
            cell.pwmField.textColor = textColor
            cell.pwmField.isEnabled = !appConfiguration.appLocked() // Enable field only if app is not locked
            cell.pwmField.text = "\(output.intValue ?? 0)"

            return cell
        } else {
            NSLog("Unsupported Output Control: \(output.type)")
            // Return dummy cell. Should never happen this case
            return tableView.dequeueReusableCell(withIdentifier: "gpio_cell", for: indexPath) as! EnclosureGPIOViewCell
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
            if let regularOutputs = data["rpi_output_regular"] as? NSArray {
                // Refresh value of regular outputs (e.g. switches)
                for case let regularOutput as NSDictionary in regularOutputs {
                    if let index = regularOutput["index_id"] as? Int16, let value = regularOutput["status"] as? Bool {
                        self.refreshOutput(index: index, value: value)
                    }
                }
            }
            if let pwmOutputs = data["rpi_output_pwm"] as? NSArray {
                // Refresh value of outputs of type PWM
                for case let pwmOutput as NSDictionary in pwmOutputs {
                    if let index = pwmOutput["index_id"] as? Int16, let value = pwmOutput["pwm_value"] as? Int16 {
                        self.refreshOutput(index: index, value: value)
                    }
                }
            }
            if let newTemps = data["set_temperature"] as? NSArray {
                // Refresh temp/humidity value of outputs of type temp_hum_control
                for case let newTemp as NSDictionary in newTemps {
                    if let index = newTemp["index_id"] as? Int16, let value = newTemp["set_temperature"] as? Int16 {
                        self.refreshOutput(index: index, value: value)
                    }
                }
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
                            // Set new value to field
                            cell.pwmField.text = "\(dutyCycle)"
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
    
    func tempControlChanged(cell: EnclosureTempControlViewCell, temp: Int) {
        if let indexPath = self.tableView.indexPath(for: cell) {
            let output = self.outputs[indexPath.row]
            let changeTempHumidityControl = {
                let generator = UINotificationFeedbackGenerator()
                generator.prepare()
                self.octoprintClient.changeEnclosureTempControl(index_id: output.index, temp: temp) { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                    if requested {
                        DispatchQueue.main.async {
                            generator.notificationOccurred(.success)
                            // Set new value to field
                            cell.pwmField.text = "\(temp)"
                            // Refresh row
                            self.tableView.reloadRows(at: [indexPath], with: .automatic)
                        }
                    } else {
                        // Handle error
                        // TODO: - Change error message
                        let message = temp > 0 ? NSLocalizedString("Failed to request to turn power on", comment: "") : NSLocalizedString("Failed to request to turn power off", comment: "")
                        self.showAlert(NSLocalizedString("Warning", comment: ""), message: message)
                    }
                }
            }
            if temp <= 0 {
                showConfirm(message: String(format: NSLocalizedString("Confirm turn off", comment: ""), output.label), yes: { (UIAlertAction) -> Void in
                    changeTempHumidityControl()
                }, no: { (UIAlertAction) -> Void in
                    // Do nothing
                })
            } else {
                changeTempHumidityControl()
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
        octoprintClient.refreshEnclosureStatus { (requested: Bool, error: Error?, response: HTTPURLResponse) in
            done?()
        }
    }
    
    fileprivate func refreshOutput(index: Int16, value: Bool) {
        for (enumIndex, outputToUpdate) in self.outputs.enumerated() {
            if index == outputToUpdate.index {
                // Update status in wrapper
                outputToUpdate.status = value
                // Refresh only row of updated status
                DispatchQueue.main.async {
                    self.tableView.reloadRows(at: [IndexPath(row: enumIndex, section: 0)], with: .automatic)
                }
            }
        }
    }
    
    fileprivate func refreshOutput(index: Int16, value: Int16) {
        for (enumIndex, outputToUpdate) in self.outputs.enumerated() {
            if index == outputToUpdate.index {
                // Update status in wrapper
                outputToUpdate.intValue = value
                // Refresh only row of updated status
                DispatchQueue.main.async {
                    self.tableView.reloadRows(at: [IndexPath(row: enumIndex, section: 0)], with: .automatic)
                }
            }
        }
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
    /// Int value only used for outputs that control temp/humid
    var intValue: Int16?
    
    init(output: EnclosureOutput) {
        self.type = output.type
        self.index = output.index_id
        self.label = output.label
        self.status = false
    }
}

