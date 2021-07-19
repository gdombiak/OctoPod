import WatchKit

class CamerasInterfaceController: WKInterfaceController, PrinterManagerDelegate {
    
    @IBOutlet weak var prevButton: WKInterfaceButton!
    @IBOutlet weak var nextButton: WKInterfaceButton!
    @IBOutlet weak var refreshButton: WKInterfaceButton!
    @IBOutlet weak var cameraImage: WKInterfaceImage!
    @IBOutlet weak var errorMessageLabel: WKInterfaceLabel!
    
    var streamingController: MjpegStreaming?
    var currentCamera: Int = 0

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Configure interface objects here.
        streamingController = MjpegStreaming(imageView: cameraImage)
        
        prevButton.setHidden(true)
        nextButton.setHidden(true)
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
        // Update "pointer" to camera being rendered
        currentCamera = currentCamera + 1
        // Remove image of current camera
        self.cameraImage.setImage(nil)
        // Render new camera
        renderPrinterCameras()
    }
    
    @IBAction func previousClicked() {
        // Update "pointer" to camera being rendered
        currentCamera = currentCamera - 1
        // Remove image of current camera
        self.cameraImage.setImage(nil)
        // Render new camera
        renderPrinterCameras()
    }
    
    @IBAction func refreshClicked() {
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
    
    // Notification that an image has been received from a received file
    // If image is nil then that means that there was an error reading
    // the file to get the image
    func imageReceived(image: UIImage?, cameraId: String) {
        // Check that display is still showing camera for which we received an image
        if cameraId == currentCameraId() {
            DispatchQueue.main.async {
                if let image = image {
                    self.cameraImage.setImage(image)
                } else {
                    self.errorMessageLabel.setText(NSLocalizedString("Connection failed", comment: ""))
                    self.errorMessageLabel.setHidden(false)
                }
                // Done refreshing so enable button again
                self.refreshButton.setEnabled(true)
            }
        }
    }

    // MARK: - Private functions
    
    fileprivate func renderPrinterCameras() {
        if let printer = PrinterManager.instance.defaultPrinter(), let cameras = PrinterManager.instance.cameras(printer: printer) {
            // Check that selected camera is still within range of cameras
            if cameras.count < (currentCamera + 1) {
                currentCamera = 0
            }

            prevButton.setHidden(currentCamera == 0)
            nextButton.setHidden(cameras.count - currentCamera <= 1)
            cameraImage.setHidden(cameras.count == 0)
            errorMessageLabel.setHidden(true)

            if !cameras.isEmpty {
                let username: String? = PrinterManager.instance.username(printer: printer)
                let password: String? = PrinterManager.instance.password(printer: printer)
                let preemptive: Bool = PrinterManager.instance.preemptive(printer: printer)
                let orientation: Int = cameras[currentCamera].orientation
                let url: String = cameras[currentCamera].url
                let cameraId: String =  currentCameraId()
                
                // Disable refresh button to indicate we are "refreshing"
                refreshButton.setEnabled(false)
                // Ask iOS App to fetch the image and resize it on the phone so it gets faster to the Apple Watch
                OctoPrintClient.instance.camera_take(url: url, username: username, password: password, preemptive: preemptive, orientation: orientation, cameraId: cameraId) { (requested: Bool, error: String?) in
                    if requested {
                        if let error = error {
                            // iOS App found an error and we need to display it in Apple Watch
                            DispatchQueue.main.async {
                                if cameraId == self.currentCameraId() {
                                    self.cameraImage.setImage(nil)
                                    // Display error messages
                                    self.errorMessageLabel.setText(error)
                                    self.errorMessageLabel.setHidden(false)
                                    // Done refreshing so enable button again
                                    self.refreshButton.setEnabled(true)
                                }
                            }
                        }
                    } else {
                        // iPhone is out of reach or some Watch Connectivity error happened
                        // Check if we can do a direct fetch from Apple Watch
                        if UIUtils.isHLS(url: url) {
                            // Show error since Apple Watch cannot render HLS feeds
                            DispatchQueue.main.async {
                                if cameraId == self.currentCameraId() {
                                    self.cameraImage.setImage(nil)
                                    // Display error messages
                                    self.errorMessageLabel.setText(NSLocalizedString("HLS not supported", comment: "Apple Watch cannot render HTTP Live Streaming feeds"))
                                    self.errorMessageLabel.setHidden(false)
                                    // Done refreshing so enable button again
                                    self.refreshButton.setEnabled(true)
                                }
                            }
                        } else {
                            // Fallback to fetching image directly from watch (might be slower)
                            self.directCameraFetch(url: url, orientation: orientation, username: username, password: password, cameraId: cameraId)
                        }
                    }
                }
            }
        } else {
            // Clean up camera info since there is no default printer
            prevButton.setHidden(true)
            nextButton.setHidden(true)
            cameraImage.setHidden(true)
            errorMessageLabel.setHidden(true)
        }
    }
    
    fileprivate func directCameraFetch(url: String, orientation: Int, username: String?, password: String?, cameraId: String) {
        // User authentication credentials if configured for the printer
        if let username = username, let password = password {
            // Handle user authentication if webcam is configured this way (I hope people are being careful and doing this)
            streamingController?.authenticationHandler = { challenge in
                let credential = URLCredential(user: username, password: password, persistence: .forSession)
                return (.useCredential, credential)
            }
        }
        
        streamingController?.authenticationFailedHandler = {
            DispatchQueue.main.async {
                if cameraId == self.currentCameraId() {
                    self.cameraImage.setImage(nil)
                    // Display error messages
                    self.errorMessageLabel.setText(NSLocalizedString("Authentication failed", comment: "HTTP authentication failed"))
                    self.errorMessageLabel.setHidden(false)
                    // Done refreshing so enable button again
                    self.refreshButton.setEnabled(true)
                }
            }
        }
        
        streamingController?.didFinishWithErrors = { error in
            DispatchQueue.main.async {
                if cameraId == self.currentCameraId() {
                    self.cameraImage.setImage(nil)
                    // Display error messages
                    self.errorMessageLabel.setText(error.localizedDescription)
                    self.errorMessageLabel.setHidden(false)
                    // Done refreshing so enable button again
                    self.refreshButton.setEnabled(true)
                }
            }
        }
        
        streamingController?.didFinishWithHTTPErrors = { httpResponse in
            // We got a 404 or some 5XX error
            DispatchQueue.main.async {
                if cameraId == self.currentCameraId() {
                    self.cameraImage.setImage(nil)
                    // Display error messages
                    self.errorMessageLabel.setText(String(format: NSLocalizedString("HTTP Request error", comment: "HTTP Request error info"), httpResponse.statusCode))
                    self.errorMessageLabel.setHidden(false)
                    // Done refreshing so enable button again
                    self.refreshButton.setEnabled(true)
                }
            }
        }
        
        streamingController?.didFinishLoading = {
            if cameraId == self.currentCameraId() {
                // Hide error messages since an image will be rendered (so that means that it worked!)
                self.errorMessageLabel.setHidden(true)
                // Done refreshing so enable button again
                self.refreshButton.setEnabled(true)
            }
            
            // Stop refreshing. A single JPEG takes a second or more to download so camera will
            // fall way behind (many frames per second). Better to download a single image and
            // then ask the next one that will be current
            self.streamingController?.stop()
        }
        
        streamingController?.imageOrientation = UIImage.Orientation(rawValue: orientation)!
        streamingController?.play(url: URL(string: url)!)
    }
    
    fileprivate func currentCameraId() -> String {
        return "\(currentCamera)"
    }
}
