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

            return cell
        }
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
            self.octoprintClient.executeCustomControl()
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
    
    fileprivate func showConfirm(message: String, yes: @escaping (UIAlertAction) -> Void, no: @escaping (UIAlertAction) -> Void) {
        let alert = UIAlertController(title: "Confirm", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: yes))
        // Use default style and not cancel style for NO so it appears on the right
        alert.addAction(UIAlertAction(title: "No", style: .default, handler: no))
        self.present(alert, animated: true) { () -> Void in
            // Nothing to do here
        }
    }
}
