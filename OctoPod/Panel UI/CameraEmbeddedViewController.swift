import UIKit

class CameraEmbeddedViewController: UIViewController {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()

    @IBOutlet weak var imageView: UIImageView!

    var streamingController: MjpegStreamingController?
    
    var embedded: Bool = true

    override func viewDidLoad() {
        super.viewDidLoad()

        streamingController = MjpegStreamingController(imageView: imageView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // Start listening to events when app comes back from background
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: Notification.Name.UIApplicationWillEnterForeground, object: nil)

        if !embedded {
            // Hide the navigation bar on the this view controller
            self.navigationController?.setNavigationBarHidden(true, animated: animated)

            // Add a gesture recognizer to camera view so we can handle taps
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleCameraTap))
            imageView.isUserInteractionEnabled = true
            imageView.addGestureRecognizer(tapGesture)
        }
        
        renderPrinter()
    }

    override func viewWillDisappear(_ animated: Bool) {
        // Stop listening to events when app comes back from background
        NotificationCenter.default.removeObserver(self)

        stopRenderingPrinter()
        
        if !embedded {
            // Show the navigation bar on other view controllers
            self.navigationController?.setNavigationBarHidden(false, animated: animated)

            // When running full screen we are forcing landscape so we go back to portrait when leaving
            UIDevice.current.setValue(Int(UIInterfaceOrientation.portrait.rawValue), forKey: "orientation")
        }
    }

    func printerSelectedChanged() {
        renderPrinter()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Navigation
    
    @objc func handleCameraTap() {
        if !embedded {
            navigationController?.popViewController(animated: true)
        }
    }

    // MARK: - Private functions

    fileprivate func renderPrinter() {
        if let printer = printerManager.getDefaultPrinter() {
            
            let url = URL(string: printer.hostname + "/webcam/?action=stream")
            
            // User authentication credentials if configured for the printer
            if let username = printer.username, let password = printer.password {
                // Handle user authentication if webcam is configured this way (I hope people are being careful and doing this)
                streamingController?.authenticationHandler = { challenge in
                    let credential = URLCredential(user: username, password: password, persistence: .forSession)
                    return (.useCredential, credential)
                }
            }

            streamingController?.authenticationFailedHandler = {
                DispatchQueue.main.async {
                    self.imageView.image = nil
                }
            }
            
            streamingController?.didFinishWithErrors = { error in
//                let errorMessage: String = error.localizedDescription
//                if errorMessage.range(of: "Transport Security policy") != nil {
//                    self.showMessage("Printer connection must use HTTPS")
//                } else if errorMessage.range(of: "connection to the server cannot be made") != nil {
//                    // "An SSL error has occurred and a secure connection to the server cannot be made."
//                    self.showMessage("Connection failed. Bad port?")
//                } else if errorMessage.range(of: "hostname could not be found") != nil {
//                    // A server with the specified hostname could not be found.
//                    self.showMessage("Connection failed. Bad hostname?")
//                } else {
//                    print(errorMessage)
//                }
                DispatchQueue.main.async {
                    self.imageView.image = nil
                }
            }
            
            streamingController?.didFinishWithHTTPErrors = { httpResponse in
                // We got a 404 or some 5XX error
//                self.showMessage("Connection successful. Got HTTP error: \(httpResponse.statusCode)")
                DispatchQueue.main.async {
                    self.imageView.image = nil
                }
            }

            // Start rendering the camera
            streamingController?.play(url: url!)
        }
    }
    
    fileprivate func stopRenderingPrinter() {
        streamingController?.stop()
    }

    @objc func appWillEnterForeground() {
        // Resume rendering printer
        renderPrinter()
    }
}
