import UIKit

class SendGCodeViewController: UITableViewController {

    @IBOutlet weak var gCodeField: UITextField!
    @IBOutlet weak var sendButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func gcodeChanged(_ sender: Any) {
        var buttonEnabled = false
        if let text = gCodeField.text {
            buttonEnabled = !text.isEmpty
        }
        sendButton.isEnabled = buttonEnabled
    }
    
    @IBAction func closeAndSend(_ sender: Any) {
        self.performSegue(withIdentifier: "backFromSendGCode", sender: self)
    }
}
