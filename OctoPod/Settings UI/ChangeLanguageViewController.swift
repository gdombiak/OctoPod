import UIKit

class ChangeLanguageViewController: ThemedDynamicUITableViewController {

    private static let CHANGE_LANGUAGE_OVERRIDE = "CHANGE_LANGUAGE_OVERRIDE"
    private static let LANGUAGE_KEY = "AppleLanguages"  // iOS key for languages

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 8
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
        default:
            fatalError("ChangeLanguageViewController has more rows than languages")
        }
        // Close this window
        self.dismiss(animated: true, completion: nil)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
