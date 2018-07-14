// Not used
import UIKit

class CameraViewController: UIViewController, UIPopoverPresentationControllerDelegate {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()

    @IBOutlet weak var printerSelectButton: UIBarButtonItem!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var messageLabel: UILabel!
    
    var streamingController: MjpegStreamingController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        streamingController = MjpegStreamingController(imageView: imageView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        showDefaultPrinter()
        // Enable or disable printer select button depending on number of printers configured
        printerSelectButton.isEnabled = printerManager.getPrinters().count > 1
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        streamingController.stop()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Message operations
    
    func showMessage(_ message: String) {
        DispatchQueue.main.async {
            self.messageLabel.isHidden = false
            self.messageLabel.text = message
        }
    }

    func hideMessage() {
        DispatchQueue.main.async {
            self.messageLabel.isHidden = true
            self.messageLabel.text = nil
        }
    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        
        if segue.identifier == "select_camera_popover", let controller = segue.destination as? SelectDefaultPrinterViewController {
            controller.popoverPresentationController!.delegate = self
            // Refresh based on new default printer
            controller.onCompletion = {
                self.showDefaultPrinter()
            }
        }
    }

    // MARK: - UIPopoverPresentationControllerDelegate
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }
    
    // MARK: - Private functions

    func showDefaultPrinter() {
        // Clean up any previous message
        hideMessage()
        
        if let printer = printerManager.getDefaultPrinter() {
            // Update window title to Camera name
            navigationItem.title = printer.name
            
            let url = URL(string: printer.hostname + "/webcam/?action=stream")
            
            // User authentication credentials if configured for the printer
            if let username = printer.username, let password = printer.password {
                // Handle user authentication if webcam is configured this way (I hope people are being careful and doing this)
                streamingController.authenticationHandler = { challenge in
                    let credential = URLCredential(user: username, password: password, persistence: .forSession)
                    return (.useCredential, credential)
                }
                
                streamingController.authenticationFailedHandler = {
                    self.showMessage("Bad authentication credentials")
                }
                
                streamingController.didFinishWithErrors = { error in
                    let errorMessage: String = error.localizedDescription
                    if errorMessage.range(of: "Transport Security policy") != nil {
                        self.showMessage("Printer connection must use HTTPS")
                    } else if errorMessage.range(of: "connection to the server cannot be made") != nil {
                        // "An SSL error has occurred and a secure connection to the server cannot be made."
                        self.showMessage("Connection failed. Bad port?")
                    } else if errorMessage.range(of: "hostname could not be found") != nil {
                        // A server with the specified hostname could not be found.
                        self.showMessage("Connection failed. Bad hostname?")
                    } else {
                        print(errorMessage)
                    }
                }
                
                streamingController.didFinishWithHTTPErrors = { httpResponse in
                    // We got a 404 or some 5XX error
                    self.showMessage("Connection successful. Got HTTP error: \(httpResponse.statusCode)")
                }
            }
            
            streamingController.play(url: url!)
        } else {
            // Display message that no printer is selected
            showMessage("Select a printer")
        }
    }
}
