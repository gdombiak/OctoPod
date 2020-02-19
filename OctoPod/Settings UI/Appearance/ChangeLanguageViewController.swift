import UIKit

class ChangeLanguageViewController: ThemedDynamicUITableViewController {

    static let CHANGE_LANGUAGE_OVERRIDE = "CHANGE_LANGUAGE_OVERRIDE"
    private static let LANGUAGE_KEY = "AppleLanguages"  // iOS key for languages

    let notificationsManager: NotificationsManager = { return (UIApplication.shared.delegate as! AppDelegate).notificationsManager }()

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 12
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "language_cell", for: indexPath)

        // Retrieve language being used
        var languageOverride: String?
        if let override = UserDefaults.standard.string(forKey: ChangeLanguageViewController.CHANGE_LANGUAGE_OVERRIDE) {
            languageOverride = override
        }

        switch indexPath.row {
        case 0:
            cell.textLabel?.text = NSLocalizedString("iOS Language", comment: "")
            cell.accessoryType = languageOverride == nil ? .checkmark : .none
        case 1:
            cell.textLabel?.text = "English"
            cell.accessoryType = languageOverride == "en" ? .checkmark : .none
        case 2:
            // German
            cell.textLabel?.text = "Deutsch"
            cell.accessoryType = languageOverride == "de" ? .checkmark : .none
        case 3:
            // Italian
            cell.textLabel?.text = "Italiano"
            cell.accessoryType = languageOverride == "it" ? .checkmark : .none
        case 4:
            // Czech
            cell.textLabel?.text = "Česky"
            cell.accessoryType = languageOverride == "cs" ? .checkmark : .none
        case 5:
            // Norwegian
            cell.textLabel?.text = "Norsk"
            cell.accessoryType = languageOverride == "nb" ? .checkmark : .none
        case 6:
            // Spanish (Spain)
            cell.textLabel?.text = "Español (España)"
            cell.accessoryType = languageOverride == "es" ? .checkmark : .none
        case 7:
            // Spanish (Latin America)
            cell.textLabel?.text = "Español (America Latina)"
            cell.accessoryType = languageOverride == "es-419" ? .checkmark : .none
        case 8:
            // Lithuanian
            cell.textLabel?.text = "Lietuvių"
            cell.accessoryType = languageOverride == "lt-LT" ? .checkmark : .none
        case 9:
            // Swedish
            cell.textLabel?.text = "Svenska"
            cell.accessoryType = languageOverride == "sv" ? .checkmark : .none
        case 10:
            // French
            cell.textLabel?.text = "Français"
            cell.accessoryType = languageOverride == "fr" ? .checkmark : .none
        case 11:
            // Russian
            cell.textLabel?.text = "Русский"
            cell.accessoryType = languageOverride == "ru" ? .checkmark : .none
        default:
            fatalError("ChangeLanguageViewController has more rows than languages")
        }

        return cell
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
            // French
            defaults.set(["ru"], forKey: ChangeLanguageViewController.LANGUAGE_KEY)
            defaults.set("ru", forKey: ChangeLanguageViewController.CHANGE_LANGUAGE_OVERRIDE)
        default:
            fatalError("ChangeLanguageViewController has more rows than languages")
        }
        
        // User changed languages so notifications coming from OctoPod plugin need to use new language
        notificationsManager.userChangedLanguage()
        
        // Close this window
        self.dismiss(animated: true, completion: nil)
    }
}
