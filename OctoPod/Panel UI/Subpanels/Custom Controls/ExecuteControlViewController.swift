import UIKit

class ExecuteControlViewController: ThemedDynamicUITableViewController {

    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()

    var control: ExecuteControl!
    var input: Array<ControlInput>!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .done, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Run", style: .done, target: self, action: #selector(execute))
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Update window title to control being executed
        navigationItem.title = control.name()

        if let newInput = control.input() {
            input = newInput
        } else {
            input = Array()
        }

        // Enable/disable run button based on parameters values
        checkRunStatus()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return input.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let controlInput = input[indexPath.row]
        if controlInput.hasSlider {
            let cell = tableView.dequeueReusableCell(withIdentifier: "input_slider_cell", for: indexPath) as! CustomControlInputSlideViewCell
            
            // Configure the cell
            cell.executeControlViewController = self
            cell.row = indexPath.row
            cell.inputLabel?.text = controlInput.name
            cell.inputLabel?.textColor = Theme.currentTheme().labelColor()
            
            cell.inputValueSlider.maximumValue = Float(controlInput.slider_max!)!
            cell.inputValueSlider.minimumValue = Float(controlInput.slider_min!)!
            cell.steps = Float(controlInput.slider_step!)
            cell.inputValueSlider.value = Float(truncating: controlInput.defaultValue! as! NSNumber)
            
            if let integer = controlInput.defaultValue as? Int {
                cell.inputValueField.text = String(integer)
            } else {
                cell.inputValueField.text = String(cell.inputValueSlider.value)
            }

            return cell

        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "input_cell", for: indexPath) as! CustomControlInputViewCell
            
            // Configure the cell
            cell.executeControlViewController = self
            cell.row = indexPath.row
            cell.inputLabel?.text = controlInput.name
            cell.inputLabel?.textColor = Theme.currentTheme().labelColor()

            if let text = controlInput.defaultValue as? String {
                cell.inputValueField.text = text
            }

            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }

    // MARK: - Notifications
    
    func valueUpdated(row: Int, value: AnyObject) {
        input[row].value = value
        // Enable/disable run button based on parameters values
        checkRunStatus()
    }

    // MARK: - Button operations
    
    @objc func execute() {
        let executeBlock = {
            let json = self.control.executePayload()
            self.octoprintClient.executeCustomControl(control: json, callback: { (requested: Bool, error: Error?, response: HTTPURLResponse) in
                if !requested {
                    // Handle error
                    NSLog("Error requesting to execute command \(json). HTTP status code \(response.statusCode)")
                    if response.statusCode == 409 {
                        self.showAlert("Alert", message: "Command not executed. Printer not operational")
                    } else if response.statusCode == 404 {
                        self.showAlert("Alert", message: "Command not executed. Script not found")
                    } else {
                        self.showAlert("Alert", message: "Failed to request to execute command")
                    }
                }
            })
        }
        
        if let confirmation = control.confirm() {
            showConfirm(message: confirmation, yes: { (alert: UIAlertAction) in
                executeBlock()
            }) { (alert: UIAlertAction) in
                // Do nothing
            }
        } else {
            executeBlock()
        }
    }

    @objc func cancel() {
        self.navigationController?.popViewController(animated: true)
    }

    // MARK: - Private functions
    
    fileprivate func checkRunStatus() {
        // Run button will be enabled only if all parameters have a value
        navigationItem.rightBarButtonItem?.isEnabled = !input.contains(where: { (input: ControlInput) -> Bool in
            return input.value == nil
        })
    }
    
    fileprivate func showAlert(_ title: String, message: String) {
        UIUtils.showAlert(presenter: self, title: title, message: message, done: nil)
    }
    
    fileprivate func showConfirm(message: String, yes: @escaping (UIAlertAction) -> Void, no: @escaping (UIAlertAction) -> Void) {
        UIUtils.showConfirm(presenter: self, message: message, yes: yes, no: no)
    }
}
