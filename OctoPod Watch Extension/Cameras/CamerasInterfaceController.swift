import WatchKit

class CamerasInterfaceController: WKInterfaceController, PrinterManagerDelegate {
    
    @IBOutlet weak var prevButton: WKInterfaceButton!
    @IBOutlet weak var nextButton: WKInterfaceButton!
    @IBOutlet weak var cameraImage: WKInterfaceImage!
    @IBOutlet weak var errorMessageLabel: WKInterfaceLabel!
    
    var streamingController: MjpegStreaming?
    var currentCamera: Int = 0

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Configure interface objects here.
        streamingController = MjpegStreaming(imageView: cameraImage)
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()

        // Listen to changes to list of printers
        PrinterManager.instance.delegates.append(self)

        // Render cameras of default printer
        renderPrinterCameras()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
        
        // Stop rendering the camera
        streamingController?.stop()

        // Stop listening to changes to list of printers
        PrinterManager.instance.remove(printerManagerDelegate: self)
    }

    // MARK: - Button actions

    @IBAction func nextClicked() {
        currentCamera = currentCamera + 1
        renderPrinterCameras()
    }
    
    @IBAction func previousClicked() {
        currentCamera = currentCamera - 1
        renderPrinterCameras()
    }
    
    // MARK: - PrinterManagerDelegate
    
    // Notification that list of printers has changed. Could be that new
    // ones were added, or updated or deleted. Change was pushed from iOS app
    // to the Apple Watch
    func printersChanged() {
        // Do nothing
    }
    
    // Notification that selected printer has changed due to a remote change
    // Remote change could be from iPhone or iPad. Local changes do not trigger
    // this notification
    func defaultPrinterChanged(newDefault: [String: Any]?) {
        // Reset camera number being shown
        currentCamera = 0
        // Start rendering from scratch
        DispatchQueue.main.async {
            self.renderPrinterCameras()
        }
    }
    
    // MARK: - Private functions
    
    fileprivate func renderPrinterCameras() {
        if let printer = PrinterManager.instance.defaultPrinter(), let cameras = PrinterManager.instance.cameras(printer: printer) {
            prevButton.setHidden(currentCamera == 0)
            nextButton.setHidden(cameras.count - currentCamera <= 1)
            cameraImage.setHidden(cameras.count == 0)
            errorMessageLabel.setHidden(true)

            if !cameras.isEmpty {
                // User authentication credentials if configured for the printer
                if let username = PrinterManager.instance.username(printer: printer), let password = PrinterManager.instance.password(printer: printer) {
                    // Handle user authentication if webcam is configured this way (I hope people are being careful and doing this)
                    streamingController?.authenticationHandler = { challenge in
                        let credential = URLCredential(user: username, password: password, persistence: .forSession)
                        return (.useCredential, credential)
                    }
                }
                
                streamingController?.authenticationFailedHandler = {
                    DispatchQueue.main.async {
                        self.cameraImage.setImage(nil)
                        // Display error messages
                        self.errorMessageLabel.setText(NSLocalizedString("Authentication failed", comment: "HTTP authentication failed"))
                        self.errorMessageLabel.setHidden(false)
                    }
                }
                
                streamingController?.didFinishWithErrors = { error in
                    DispatchQueue.main.async {
                        self.cameraImage.setImage(nil)
                        // Display error messages
                        self.errorMessageLabel.setText(error.localizedDescription)
                        self.errorMessageLabel.setHidden(false)
                    }
                }
                
                streamingController?.didFinishWithHTTPErrors = { httpResponse in
                    // We got a 404 or some 5XX error
                    DispatchQueue.main.async {
                        self.cameraImage.setImage(nil)
                        // Display error messages
                        self.errorMessageLabel.setText(String(format: NSLocalizedString("HTTP Request error", comment: "HTTP Request error info"), httpResponse.statusCode))
                        self.errorMessageLabel.setHidden(false)
                    }
                }
                
                streamingController?.didFinishLoading = {
                    // Hide error messages since an image will be rendered (so that means that it worked!)
                    self.errorMessageLabel.setHidden(true)
                }
                
//                streamingController?.didRendered = {
//                    // Show timestamp to know when image was refreshed. Helps troubleshoot delays during development
//                    let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: DateFormatter.Style.none, timeStyle: DateFormatter.Style.medium)
//                    self.errorMessageLabel.setText(timestamp)
//                    self.errorMessageLabel.setHidden(false)
//                }

                streamingController?.imageOrientation = UIImage.Orientation(rawValue: cameras[currentCamera].orientation)!
                streamingController?.play(url: URL(string: cameras[currentCamera].url)!)
            }

        } else {
            // Clean up camera info since there is no default printer
            prevButton.setHidden(true)
            nextButton.setHidden(true)
            cameraImage.setHidden(true)
            errorMessageLabel.setHidden(true)
        }
    }
}
