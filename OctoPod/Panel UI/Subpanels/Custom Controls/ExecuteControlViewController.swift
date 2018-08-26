import UIKit

class ExecuteControlViewController: ThemedDynamicUITableViewController {

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
            let cell = tableView.dequeueReusableCell(withIdentifier: "input_slider_cell", for: indexPath)
            
            // Configure the cell
            cell.textLabel?.text = controlInput.name
            
            return cell

        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "input_cell", for: indexPath)
            
            // Configure the cell
            cell.textLabel?.text = controlInput.name

            return cell
        }
    }
    
    // MARK: - Button operations
    
    @objc func execute() {
        
    }

    @objc func cancel() {
        self.navigationController?.popViewController(animated: true)
    }
}
