import UIKit

class SponsorsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, SponsorTableViewCellDelegate {

    private var currentTheme: Theme.ThemeChoice!

    @IBOutlet weak var sponsorsTable: UITableView!
    @IBOutlet weak var becomeSponsorButton: UIButton!
    
    private var sponsors: Array<Sponsor> = []
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Remember current theme so we know when to repaint
        currentTheme = Theme.currentTheme()

        // Populate list of active sponsors
        sponsors.append(Sponsor(name: "Juha Kuusama", link: nil))
        sponsors.append(Sponsor(name: "Jesse Armstrong", link: "https://github.com/jessearmstrong"))
        sponsors.append(Sponsor(name: "Josh Wright (tideline3d)", link: "https://github.com/tideline3d"))
        sponsors.append(Sponsor(name: "Manojav Sridhar", link: "https://github.com/vajonam"))
        sponsors.append(Sponsor(name: "Chris Kuipers", link: "https://github.com/chriskuipers"))
        sponsors.append(Sponsor(name: "Brad McGonigle", link: "https://github.com/BradMcGonigle"))
        sponsors.append(Sponsor(name: "Manuel McLure", link: "https://github.com/ManuelMcLure"))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if currentTheme != Theme.currentTheme() {
            // Theme changed so repaint table now (to prevent quick flash in the UI with the old theme)
            sponsorsTable.reloadData()
            currentTheme = Theme.currentTheme()
        }
        // Paint UI based on theme
        ThemeUIUtils.applyTheme(table: sponsorsTable, staticCells: false)
        // Set background color to the view
        view.backgroundColor = currentTheme.backgroundColor()
        becomeSponsorButton.tintColor = currentTheme.tintColor()
    }
    
    @IBAction func becomeSponsorClicked(_ sender: Any) {
        if let url = URL(string: "https://github.com/sponsors/gdombiak") {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sponsors.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "sponsorCell", for: indexPath) as! SponsorTableViewCell

        cell.delegate = self
        
        cell.sponsorNameLabel.text = sponsors[indexPath.row].name
        cell.sponsorLinkButton.isHidden = sponsors[indexPath.row].link == nil

        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        ThemeUIUtils.themeCell(cell: cell)
        
        if let cell = cell as? SponsorTableViewCell {
            cell.sponsorNameLabel.textColor = Theme.currentTheme().textColor()
        }
    }
    
    // MARK: - SponsorTableViewCellDelegate
    
    func sponsorLinkClicked(cell: SponsorTableViewCell) {
        if let indexPath = self.sponsorsTable.indexPath(for: cell), let link = sponsors[indexPath.row].link, let url = URL(string: link) {
            UIApplication.shared.open(url)
        }
    }
}

struct Sponsor {
    var name: String
    var link: String?
}
