import UIKit

class ChangeLanguageViewController: ThemedDynamicUITableViewController {

    static let CHANGE_LANGUAGE_OVERRIDE = "CHANGE_LANGUAGE_OVERRIDE"
    private static let LANGUAGE_KEY = "AppleLanguages"  // iOS key for languages

    let notificationsManager: NotificationsManager = { return (UIApplication.shared.delegate as! AppDelegate).notificationsManager }()

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        updatePopoverSize()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updatePopoverSize()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            updatePopoverSize()
            tableView.reloadData()
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 14
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "language_cell", for: indexPath)
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.lineBreakMode = .byWordWrapping
        cell.textLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        cell.textLabel?.adjustsFontForContentSizeCategory = true
        cell.textLabel?.adjustsFontSizeToFitWidth = false

        // Retrieve language being used
        var languageOverride: String?
        if let override = UserDefaults.standard.string(forKey: ChangeLanguageViewController.CHANGE_LANGUAGE_OVERRIDE) {
            languageOverride = override
        }

        cell.textLabel?.text = languageTitle(for: indexPath.row)
        switch indexPath.row {
        case 0:
            cell.accessoryType = languageOverride == nil ? .checkmark : .none
        case 1:
            cell.accessoryType = languageOverride == "en" ? .checkmark : .none
        case 2:
            cell.accessoryType = languageOverride == "de" ? .checkmark : .none
        case 3:
            cell.accessoryType = languageOverride == "it" ? .checkmark : .none
        case 4:
            cell.accessoryType = languageOverride == "cs" ? .checkmark : .none
        case 5:
            cell.accessoryType = languageOverride == "nb" ? .checkmark : .none
        case 6:
            cell.accessoryType = languageOverride == "es" ? .checkmark : .none
        case 7:
            cell.accessoryType = languageOverride == "es-419" ? .checkmark : .none
        case 8:
            cell.accessoryType = languageOverride == "lt-LT" ? .checkmark : .none
        case 9:
            cell.accessoryType = languageOverride == "sv" ? .checkmark : .none
        case 10:
            cell.accessoryType = languageOverride == "fr" ? .checkmark : .none
        case 11:
            cell.accessoryType = languageOverride == "ru" ? .checkmark : .none
        case 12:
            cell.accessoryType = languageOverride == "nl" ? .checkmark : .none
        case 13:
            cell.accessoryType = languageOverride == "zh-Hans" ? .checkmark : .none
        default:
            fatalError("ChangeLanguageViewController has more rows than languages")
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let font = UIFont.preferredFont(forTextStyle: .body)
        let width = max((tableView.bounds.width > 1 ? tableView.bounds.width : 320) - 88, 80)
        let title = languageTitle(for: indexPath.row) as NSString
        let rect = title.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil)
        return max(44, ceil(rect.height) + 24)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let defaults = UserDefaults.standard
        switch indexPath.row {
        case 0:
            defaults.removeObject(forKey: ChangeLanguageViewController.LANGUAGE_KEY)
            defaults.removeObject(forKey: ChangeLanguageViewController.CHANGE_LANGUAGE_OVERRIDE)
        case 1:
            defaults.set(["en"], forKey: ChangeLanguageViewController.LANGUAGE_KEY)
            defaults.set("en", forKey: ChangeLanguageViewController.CHANGE_LANGUAGE_OVERRIDE)
        case 2:
            // German
            defaults.set(["de"], forKey: ChangeLanguageViewController.LANGUAGE_KEY)
            defaults.set("de", forKey: ChangeLanguageViewController.CHANGE_LANGUAGE_OVERRIDE)
        case 3:
            // Italian
            defaults.set(["it"], forKey: ChangeLanguageViewController.LANGUAGE_KEY)
            defaults.set("it", forKey: ChangeLanguageViewController.CHANGE_LANGUAGE_OVERRIDE)
        case 4:
            // Czech
            defaults.set(["cs"], forKey: ChangeLanguageViewController.LANGUAGE_KEY)
            defaults.set("cs", forKey: ChangeLanguageViewController.CHANGE_LANGUAGE_OVERRIDE)
        case 5:
            // Norwegian
            defaults.set(["nb"], forKey: ChangeLanguageViewController.LANGUAGE_KEY)
            defaults.set("nb", forKey: ChangeLanguageViewController.CHANGE_LANGUAGE_OVERRIDE)
        case 6:
            // Spanish (Spain)
            defaults.set(["es"], forKey: ChangeLanguageViewController.LANGUAGE_KEY)
            defaults.set("es", forKey: ChangeLanguageViewController.CHANGE_LANGUAGE_OVERRIDE)
        case 7:
            // Spanish (Latin America)
            defaults.set(["es-419"], forKey: ChangeLanguageViewController.LANGUAGE_KEY)
            defaults.set("es-419", forKey: ChangeLanguageViewController.CHANGE_LANGUAGE_OVERRIDE)
        case 8:
            // Lithuanian
            defaults.set(["lt-LT"], forKey: ChangeLanguageViewController.LANGUAGE_KEY)
            defaults.set("lt-LT", forKey: ChangeLanguageViewController.CHANGE_LANGUAGE_OVERRIDE)
        case 9:
            // Swedish
            defaults.set(["sv"], forKey: ChangeLanguageViewController.LANGUAGE_KEY)
            defaults.set("sv", forKey: ChangeLanguageViewController.CHANGE_LANGUAGE_OVERRIDE)
        case 10:
            // French
            defaults.set(["fr"], forKey: ChangeLanguageViewController.LANGUAGE_KEY)
            defaults.set("fr", forKey: ChangeLanguageViewController.CHANGE_LANGUAGE_OVERRIDE)
        case 11:
            // Russian
            defaults.set(["ru"], forKey: ChangeLanguageViewController.LANGUAGE_KEY)
            defaults.set("ru", forKey: ChangeLanguageViewController.CHANGE_LANGUAGE_OVERRIDE)
        case 12:
            // Nederlands
            defaults.set(["nl"], forKey: ChangeLanguageViewController.LANGUAGE_KEY)
            defaults.set("nl", forKey: ChangeLanguageViewController.CHANGE_LANGUAGE_OVERRIDE)
        case 13:
            // Simplified Chinese
            defaults.set(["zh-Hans"], forKey: ChangeLanguageViewController.LANGUAGE_KEY)
            defaults.set("zh-Hans", forKey: ChangeLanguageViewController.CHANGE_LANGUAGE_OVERRIDE)
        default:
            fatalError("ChangeLanguageViewController has more rows than languages")
        }
        
        // User changed languages so notifications coming from OctoPod plugin need to use new language
        notificationsManager.userChangedLanguage()
        
        // Close this window
        self.dismiss(animated: true, completion: nil)
    }

    private func languageTitle(for row: Int) -> String {
        switch row {
        case 0:
            return NSLocalizedString("iOS Language", comment: "")
        case 1:
            return "English"
        case 2:
            return "Deutsch"
        case 3:
            return "Italiano"
        case 4:
            return "Česky"
        case 5:
            return "Norsk"
        case 6:
            return "Español (España)"
        case 7:
            return "Español (America Latina)"
        case 8:
            return "Lietuvių"
        case 9:
            return "Svenska"
        case 10:
            return "Français"
        case 11:
            return "Русский"
        case 12:
            return "Nederlands"
        case 13:
            return "简体中文"
        default:
            return ""
        }
    }

    /// The storyboard popover is 250 by 370. Long names and accessibility text
    /// need a wider list that still scrolls inside the screen.
    private func updatePopoverSize() {
        let host = presentingViewController?.view
        let bounds = host?.bounds ?? UIScreen.main.bounds
        let safeArea = host?.safeAreaInsets ?? .zero
        var sourceFrame: CGRect?
        if let host, let source = popoverPresentationController?.sourceView {
            let rect = popoverPresentationController?.sourceRect ?? source.bounds
            sourceFrame = source.convert(rect, to: host)
        }
        preferredContentSize = ChangeLanguageViewController.popoverSize(fitting: bounds, sourceFrame: sourceFrame, safeArea: safeArea)
    }

    /// Width stays at most 440. Height prefers 55% of the host, and shrinks when
    /// that would be taller than the space on either side of the source button.
    static func popoverSize(fitting bounds: CGRect, sourceFrame: CGRect?, safeArea: UIEdgeInsets) -> CGSize {
        let width = min(max(bounds.width - 40, 280), 440)
        var height = min(max(bounds.height * 0.55, 280), 640)
        if let sourceFrame {
            let above = sourceFrame.minY - safeArea.top
            let below = bounds.height - safeArea.bottom - sourceFrame.maxY
            let room = max(above, below) - 16
            if room >= 160 {
                height = min(height, room)
            }
        }
        return CGSize(width: width, height: height)
    }
}
