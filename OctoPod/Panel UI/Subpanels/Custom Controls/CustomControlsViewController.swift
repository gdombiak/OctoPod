import UIKit
import SafariServices  // Used for opening browser in-app

class CustomControlsViewController: ThemedDynamicUITableViewController, SubpanelViewController {

    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()

    @IBOutlet var footerView: UIView!
    @IBOutlet private var helpButtons: [UIButton]!
    @IBOutlet private weak var helpFooterBottom: NSLayoutConstraint!
    
    var containers: Array<Container>?

    override func viewDidLoad() {
        super.viewDidLoad()
        updateHelpButtonFonts()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        sizeHelpFooter()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard isViewLoaded, previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory else { return }
        updateHelpButtonFonts()
        tableView.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Theme footer
        let theme = Theme.currentTheme()
        footerView.backgroundColor = theme.cellBackgroundColor()
        // Set color (and text) to refresh control
        if let refreshControl = refreshControl {
            ThemeUIUtils.applyTheme(refreshControl: refreshControl)
        }

        // Hide footer. Will appear only if no custom controls were found
        tableView.tableFooterView = nil
        
        // Fetch and render custom controls
        refreshCustomControls(done: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return containers == nil ? 0 : containers!.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return NSLocalizedString("Custom Controls", comment: "http://docs.octoprint.org/en/master/features/custom_controls.html")
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory,
           let height = SettingsDynamicTypeLayout.height(
               for: self.tableView(tableView, titleForHeaderInSection: section),
               width: tableView.bounds.width, style: .footnote) {
            return height
        }
        return 36
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        super.tableView(tableView, willDisplayHeaderView: view, forSection: section)
        (view as? UITableViewHeaderFooterView)?.textLabel?.numberOfLines = 0
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return tableView.tableFooterView == nil ? 1 : 50
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "container_cell", for: indexPath)

        // Configure the cell
        if let containersArray = containers {
            cell.textLabel?.text = containersArray[indexPath.row].name()
            cell.textLabel?.textColor = Theme.currentTheme().labelColor()
            cell.textLabel?.numberOfLines = 0
        }

        return cell
    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "gotoChildren" {
            if let controller = segue.destination as? ChildrenCustomControlViewController, let selected = tableView.indexPathForSelectedRow, let allContainers = containers {
                controller.rootControlsVC = self
                controller.container = allContainers[selected.row]
            }
        }
    }
    
    // MARK: - SubpanelViewController

    func printerSelectedChanged() {
        // Only refresh UI if view controller is being shown
        DispatchQueue.main.async {
            if let _ = self.parent {
                // Fetch and render custom controls
                self.refreshCustomControls(done: nil)
            }
        }
    }
    
    func currentStateUpdated(event: CurrentStateEvent) {
        // Do nothing
    }
    
    func position() -> Int {
        return 50
    }
    
    // MARK: - Unwind operations

    @IBAction func gobackToRootFolder(_ sender: UIStoryboardSegue) {
        // Containers have been refreshed so just update UI
        self.tableView.reloadData()
    }
    
    // MARK: - Button operations
    
    @IBAction func clickedOnLearnMore(_ sender: Any) {
        let svc = SFSafariViewController(url: URL(string: "http://docs.octoprint.org/en/master/features/custom_controls.html")!)
        self.present(svc, animated: true, completion: nil)
    }
    
    @IBAction func clickedOnUsePlugin(_ sender: Any) {
        let svc = SFSafariViewController(url: URL(string: "https://plugins.octoprint.org/plugins/customControl")!)
        self.present(svc, animated: true, completion: nil)
    }
    
    // MARK: - Refresh

    @IBAction func refreshControls(_ sender: UIRefreshControl) {
        // Fetch and render custom controls
        refreshCustomControls(done: {
            DispatchQueue.main.async {
                sender.endRefreshing()
            }
        })
    }
    
    // Refresh custom controls from OctoPrint and call me back with the refreshed container that was specified (if found)
    func refreshContainer(container: Container, callback: @escaping ((Container?) -> Void)) {
        refreshCustomControls(done: {
            if let allContainers = self.containers {
                for rootContainer in allContainers {
                    if let found = rootContainer.locate(container: container) {
                        callback(found)
                        return
                    }
                }
            }
            // Could happen if folder no longer exists
            callback(nil)
        })
    }

    // MARK: - Private functions

    private func updateHelpButtonFonts() {
        // Leave scroll room above the panel's page indicator or connection banner.
        helpFooterBottom.constant = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 32 : 5
        let font = UIFontMetrics(forTextStyle: .footnote).scaledFont(
            for: .systemFont(ofSize: 14), compatibleWith: traitCollection)
        for button in helpButtons {
            var configuration = button.configuration ?? .plain()
            configuration.title = button.title(for: .normal) ?? configuration.title
            configuration.titleAlignment = .center
            configuration.titleLineBreakMode = .byWordWrapping
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes
                attributes.font = font
                return attributes
            }
            button.configuration = configuration
        }
        view.setNeedsLayout()
    }

    private func sizeHelpFooter() {
        guard tableView.tableFooterView != nil, tableView.bounds.width > 0 else { return }
        let width = tableView.bounds.width
        let height = ceil(footerView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height)
        let size = CGSize(width: width, height: height)
        // UITableView uses the footer's frame height even when its contents use Auto Layout.
        if footerView.frame.size != size {
            footerView.frame.size = size
            tableView.tableFooterView = footerView
        }
    }
    
    fileprivate func refreshCustomControls(done: (() -> Void)?) {
        octoprintClient.customControls { (containers: Array<Container>?, error: Error?, response: HTTPURLResponse) in
            DispatchQueue.main.async {
                self.containers = containers
                if self.isViewLoaded {
                    self.tableView.tableFooterView = containers?.isEmpty == false ? nil : self.footerView
                    self.sizeHelpFooter()
                    self.tableView.reloadData()
                }
                if let error {
                    self.showAlert(NSLocalizedString("Warning", comment: ""), message: error.localizedDescription)
                } else if response.statusCode != 200 {
                    self.showAlert(NSLocalizedString("Warning", comment: ""), message: String(format: NSLocalizedString("Failed to get controls", comment: "Failed to get controls with HTTP Request error info"), response.statusCode))
                }
                done?()
            }
        }
    }
    
    fileprivate func showAlert(_ title: String, message: String) {
        UIUtils.showAlert(presenter: self, title: title, message: message, done: nil)
    }
}
