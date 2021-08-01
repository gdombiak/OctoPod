import UIKit
import WebKit

class AddOctoEverywherePrinterViewController: BasePrinterDetailsViewController, WKUIDelegate, WKNavigationDelegate {
    
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var webView: WKWebView!
    var newWebviewPopupWindow: WKWebView?

    @IBOutlet weak var printerNameField: UITextField!
    @IBOutlet weak var apiKeyField: UITextField!
    @IBOutlet weak var scanAPIKeyButton: UIButton!

    @IBOutlet weak var includeDashboardLabel: UILabel!
    @IBOutlet weak var includeDashboardSwitch: UISwitch!
    @IBOutlet weak var showCameraLabel: UILabel!
    @IBOutlet weak var showCameraSwitch: UISwitch!

    @IBOutlet weak var saveButton: UIBarButtonItem!
    
    /// Hostname provided by OctoEverywhere
    var hostname: String?
    /// Username provided by OctoEverywhere
    var username: String?
    /// Password provided by OctoEverywhere
    var password: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        webView.navigationDelegate = self
        webView.uiDelegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        themeLabels()

        let url = URL(string: "https://octoeverywhere.com/appportal/v1/?appid=octopod&authType=enhanced&appLogoUrl=http%3A%2F%2Foctopodprint.com%2Foctopod.png")!
        webView.load(URLRequest(url: url))
        
        displayProgressMessage(message: NSLocalizedString("Select printer from OctoEverywhere.", comment: ""))
    }
    
    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row == 1 {
            if let _ = hostname {
                // Hide webview row since we user selected printer from OctoEverywhere
                return 0
            }
            // Show webView row until user selects printer from OctoEverywhere
            return tableView.frame.height * 0.7
        } else if indexPath.row > 1 {
            if let _ = hostname {
                // Show row once user selected printer from OctoEverywhere
                return UITableView.automaticDimension
            }
            // Hide row until user selects printer from OctoEverywhere
            return 0
        }
        return super.tableView(tableView, heightForRowAt: indexPath)
    }

    // MARK: WKUIDelegate
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
//            NSLog("createWebViewWith: \(navigationAction.request.url!.absoluteString)")

            newWebviewPopupWindow = WKWebView(frame: view.bounds, configuration: configuration)
            newWebviewPopupWindow!.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            newWebviewPopupWindow!.navigationDelegate = self
            newWebviewPopupWindow!.uiDelegate = self
            view.addSubview(newWebviewPopupWindow!)
            return newWebviewPopupWindow!
        }
        return nil
    }
    
    func webViewDidClose(_ webView: WKWebView) {
        webView.removeFromSuperview()
        newWebviewPopupWindow = nil
    }
        
    // MARK: WKNavigationDelegate
    
//    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
////        NSLog("ALLOW RESPONSE: \(webView.url?.absoluteString)")
//        decisionHandler(.allow)
//    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
//        guard let requestURL = navigationAction.request.url?.absoluteString else { return }
//        NSLog("ALLOW ACTION: \(requestURL)")
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
//        NSLog("webView url \(webView.url!.absoluteString)")
        
        if let url = webView.url {
            if url.host == "octoeverywhere.com" && url.path == "/appportal/v1/complete", let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                if let success = urlComponents.queryItems?.first(where: { $0.name == "success" })?.value, success == "true" {
                    if let printerURL = urlComponents.queryItems?.first(where: { $0.name == "url" })?.value, let printername = urlComponents.queryItems?.first(where: { $0.name == "printername" })?.value, let authbasichttpuser = urlComponents.queryItems?.first(where: { $0.name == "authbasichttpuser" })?.value, let authbasichttppassword = urlComponents.queryItems?.first(where: { $0.name == "authbasichttppassword" })?.value {
                        hostname = printerURL
                        username = authbasichttpuser
                        password = authbasichttppassword
                        DispatchQueue.main.async {
                            self.printerNameField.text = printername
                            self.updateSaveButton()
                            // Change status message
                            self.statusLabel.text = NSLocalizedString("Complete information and click save to finish.", comment: "")
                            self.statusLabel.textColor = UIColor.systemGreen
                            // Reload table to hide webView row and show other rows
                            self.tableView.reloadData()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - IB Events

    @IBAction func fieldChanged(_ sender: Any) {
        updateSaveButton()
    }

    @IBAction func cancelChanges(_ sender: Any) {
        goBack()
    }
    
    @IBAction func saveChanges(_ sender: Any) {
        // Add new printer (that will become default if it's the first one)
        createPrinter(connectionType: .octoEverywhere, name: printerNameField.text!, hostname: hostname!, apiKey: apiKeyField.text!, username: username!, password: password!, position: newPrinterPosition, includeInDashboard: includeDashboardSwitch.isOn, showCamera: showCameraSwitch.isOn)
        goBack()
    }
    
    // MARK: - Unwind operations
    
    @IBAction func unwindScanQRCode(_ sender: UIStoryboardSegue) {
        if let scanner = sender.source as? ScannerViewController {
            self.apiKeyField.text = scanner.scannedQRCode
            self.updateSaveButton()
        }
    }

    // MARK: - Private functions

    fileprivate func updateSaveButton() {
        if appConfiguration.appLocked() {
            // Cannot save printer info if app is locked(read-only mode)
            saveButton.isEnabled = false
            return
        }
        if !(printerNameField.text?.isEmpty)! && !(apiKeyField.text?.isEmpty)! {
            saveButton.isEnabled = true
        } else {
            saveButton.isEnabled = false
        }
    }
    
    fileprivate func themeLabels() {
        // Theme labels
        let theme = Theme.currentTheme()
        let tintColor = theme.tintColor()
        let placeHolderAttributes: [ NSAttributedString.Key : Any ] = [.foregroundColor: theme.placeholderColor()]
        scanAPIKeyButton.tintColor = tintColor
        apiKeyField.backgroundColor = theme.backgroundColor()
        apiKeyField.attributedPlaceholder = NSAttributedString(string: NSLocalizedString("API Key or Application Key", comment: ""), attributes: placeHolderAttributes)
        apiKeyField.textColor = theme.textColor()
        includeDashboardLabel.textColor = theme.textColor()
        showCameraLabel.textColor = theme.textColor()
        printerNameField.backgroundColor = theme.backgroundColor()
        printerNameField.attributedPlaceholder = NSAttributedString(string: NSLocalizedString("Printer Name (e.g. MK3)", comment: ""), attributes: placeHolderAttributes)
        printerNameField.textColor = theme.textColor()
    }

    fileprivate func displayProgressMessage(message: String) {
        DispatchQueue.main.async {
            self.statusLabel.text = message
            self.statusLabel.textColor = Theme.currentTheme().textColor()
       }
    }

    fileprivate func displayErrorMessage(message: String) {
        DispatchQueue.main.async {
            self.statusLabel.text = message
            self.statusLabel.textColor = UIColor.red
       }
    }
}
