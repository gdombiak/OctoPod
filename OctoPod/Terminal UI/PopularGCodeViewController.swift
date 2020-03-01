import UIKit

class PopularGCodeViewController: ThemedDynamicUITableViewController {
    
    private var commands: Array<(name: String, code:String, example: String)> = Array()
    var selected = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        commands.append((name: NSLocalizedString("Save Settings", comment: "gcode name"), code: "M500", example: "M500"))
        commands.append((name: NSLocalizedString("Restore Settings", comment: "gcode name"), code: "M501", example: "M501"))
        commands.append((name: NSLocalizedString("Report Settings", comment: "gcode name"), code: "M503", example: "M503"))

        commands.append((name: NSLocalizedString("PID Hotend autotune", comment: "gcode name"), code: "M303", example: "M303 E0 S215 C8 U1"))
        commands.append((name: NSLocalizedString("Set Hotend PID", comment: "gcode name"), code: "M301", example: "M301 D<value> I<value> P<value>"))
        commands.append((name: NSLocalizedString("PID Bed autotune", comment: "gcode name"), code: "M303", example: "M303 E-1 S60 C8 U1"))
        commands.append((name: NSLocalizedString("Set Bed PID", comment: "gcode name"), code: "M304", example: "M304 D<value> I<value> P<value>"))

        commands.append((name: NSLocalizedString("TMC Debugging", comment: "gcode name"), code: "M122", example: "M122"))
        commands.append((name: NSLocalizedString("TMC Motor Current", comment: "gcode name"), code: "M906", example: "M906 X<mA> Y<mA> Z<mA>"))
        commands.append((name: NSLocalizedString("TMC Bump Sensitivity", comment: "gcode name"), code: "M914", example: "M914 X<int> Y<int> Z<int>"))

        commands.append((name: NSLocalizedString("Endstop States", comment: "gcode name"), code: "M119", example: "M119"))

        commands.append((name: NSLocalizedString("Load filament", comment: "gcode name"), code: "M701", example: "M701"))
        commands.append((name: NSLocalizedString("Unload filament", comment: "gcode name"), code: "M702", example: "M702"))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Clear any previously selected gcode
        selected = ""
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return commands.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "gcode_cell", for: indexPath)

        // Configure the cell...
        cell.textLabel?.text = commands[indexPath.row].name
        cell.detailTextLabel?.text = commands[indexPath.row].code

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selected = commands[indexPath.row].example
        // Close window
        performSegue(withIdentifier: "backFromPopularGCode", sender: self)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
