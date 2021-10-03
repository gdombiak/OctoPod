import UIKit

class PrinterFullScreenCameraViewController: UIViewController, PrinterObserverDelegate, CameraViewDelegate {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()

    @IBOutlet weak var nextPrinterButton: UIButton!
    @IBOutlet weak var previousPrinterButton: UIButton!
    var camerasViewController: CamerasViewController?

    var printerURL: String!
    var printerObserver: PrinterObserver!

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let camerasChild = children.last as? CamerasViewController else {
            fatalError("Check storyboard for missing CamerasViewController")
        }
        camerasViewController = camerasChild
        
        // Create printer observer that will listen to OctoPrint events
        printerObserver = PrinterObserver(delegate: self, row: 0)
        
        // Add a gesture recognizer to camera view so we can handle taps
        camerasViewController?.embeddedCameraTappedCallback = {(CameraEmbeddedViewController) in
            DispatchQueue.main.async {
                self.performSegue(withIdentifier: "selectedPrinterFromFullScreenWithUnwindSegue", sender: self)
            }
        }
        // Only offer PIP (if supported by device) from main panel window
        camerasViewController?.offerPIP = false
        
        // Listen to event when new camera is selected so we can overlay print progres information
        camerasViewController?.embeddedCameraDelegate = self
    }
    

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Theme background color
        let currentTheme = Theme.currentTheme()
        view.backgroundColor = currentTheme.backgroundColor()

        // Hide tab bar (located at the bottom)
        self.tabBarController?.tabBar.isHidden = true

        refreshDisplayForCurrentPrinter()
        // Display print status to provide more useful information
        camerasViewController?.displayPrintStatus(enabled: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Show tab bar (located at the bottom)
        self.tabBarController?.tabBar.isHidden = false
    }
    
    // MARK: - Button operations

    @IBAction func nextPrinterClicked(_ sender: Any) {
        let printersToShow = filterPrintersToShow()
        let printerIndex: Int? = indexOfCurrentPrinter(printersToShow)

        if let index = printerIndex {
            // Get next printer
            let newPrinter = printersToShow[index + 1]
            // Update printer to show
            printerURL = newPrinter.objectID.uriRepresentation().absoluteString
            // Refresh UI
            refreshDisplayForCurrentPrinter()
            // Indicate camerasVC that we have a new printer
            camerasViewController?.printerSelectedChanged()
            // Display print status to provide more useful information
            camerasViewController?.displayPrintStatus(enabled: true)
        }
    }

    @IBAction func previousPrinterClicked(_ sender: Any) {
        let printersToShow = filterPrintersToShow()
        let printerIndex: Int? = indexOfCurrentPrinter(printersToShow)

        if let index = printerIndex {
            // Get next printer
            let newPrinter = printersToShow[index - 1]
            // Update printer to show
            printerURL = newPrinter.objectID.uriRepresentation().absoluteString
            // Refresh UI
            refreshDisplayForCurrentPrinter()
            // Indicate camerasVC that we have a new printer
            camerasViewController?.printerSelectedChanged()
            // Display print status to provide more useful information
            camerasViewController?.displayPrintStatus(enabled: true)
        }
    }

    // MARK: - PrinterObserverDelegate
    
    func currentStateUpdated(row: Int, event: CurrentStateEvent) {
        DispatchQueue.main.async {
            self.camerasViewController?.currentStateUpdated(event: event)
        }
    }
    
    // MARK: - CameraViewDelegate
    
    func finishedTransitionNewPage() {
        // Display print status to provide more useful information
        camerasViewController?.displayPrintStatus(enabled: false)
        camerasViewController?.displayPrintStatus(enabled: true)
    }

    // MARK: - Private functions
    
    fileprivate func filterPrintersToShow() -> [Printer] {
        return printerManager.getPrinters().filter { printer in
            return printer.includeInDashboard && !printer.hideCamera
        }
    }
    
    fileprivate func indexOfCurrentPrinter(_ printersToShow: [Printer]) -> Array<Printer>.Index? {
        return printersToShow.firstIndex { printer in
            return printerURL == printer.objectID.uriRepresentation().absoluteString
        }
    }
    
    fileprivate func refreshDisplayForCurrentPrinter() {
        let printersToShow = filterPrintersToShow()
        let printerIndex: Int? = indexOfCurrentPrinter(printersToShow)

        // Check if we have next and previous printers
        if let printerIndex = printerIndex {
            previousPrinterButton.isHidden = printerIndex == 0 // hide if first printer
            nextPrinterButton.isHidden = printerIndex == (printersToShow.count - 1) // hide if last printer
        } else {
            previousPrinterButton.isHidden = true
            nextPrinterButton.isHidden = true
        }

        // Display cameras for this printer
        camerasViewController?.showPrinter = printerURL

        // Stop listening to OctoPrint events (if we are switching printers)
        printerObserver.disconnectFromServer()
        
        // Update window title and start listeing to OctoPrint events
        if let idURL = URL(string: printerURL), let printer = printerManager.getPrinterByObjectURL(url: idURL) {
            self.navigationItem.title = printer.name
            self.printerObserver.connectToServer(printer: printer)
        }
    }
}
