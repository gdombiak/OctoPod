import UIKit

class MoveViewController: UIViewController {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if let printer = printerManager.getDefaultPrinter() {
            // Update window title to Camera name
            navigationItem.title = printer.name
        } else {
            navigationItem.title = "Move"
        }
    }

}
