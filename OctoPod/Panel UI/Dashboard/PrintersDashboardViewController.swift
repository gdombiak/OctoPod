import UIKit

private let reuseIdentifier = "PrinterCell"

class PrintersDashboardViewController: UICollectionViewController {

    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    var printers: Array<PrinterObserver> = []
    var panelViewController: PanelViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Disable estimated size for iOS 10 since it crashes on iPad and iPhone Plus
        let os = ProcessInfo().operatingSystemVersion
        if let layout = self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.estimatedItemSize = os.majorVersion == 10 ? CGSize(width: 0, height: 0) : UICollectionViewFlowLayout.automaticSize
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let currentTheme = Theme.currentTheme()
        collectionView.backgroundColor = currentTheme.backgroundColor()
        
        printers = []
        for printer in printerManager.getPrinters() {
            let printerObserver = PrinterObserver(printersDashboardViewController: self, row: printers.count)
            printerObserver.connectToServer(printer: printer)
            printers.append(printerObserver)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        for printerObserver in printers {
            printerObserver.disconnectFromServer()
        }
        printers = []
    }
    
    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return printers.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! PrinterViewCell
    
        // Configure the cell
        let printerObserver = printers[indexPath.row]
        cell.printerLabel.text = printerObserver.printerName
        cell.printerStatusLabel.text = printerObserver.printerStatus
        cell.progressLabel.text = printerObserver.progress
        cell.printTimeLeftLabel.text = printerObserver.printTimeLeft
        cell.layerLabel.text = printerObserver.layer
    
        return cell
    }

    // MARK: UICollectionViewDelegate
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let printer = printerManager.getPrinterByName(name: printers[indexPath.row].printerName) {
            // Notify of newly selected printer
            panelViewController?.changeDefaultPrinter(printer: printer)
            // Close this window and go back
            navigationController?.popViewController(animated: true)
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let theme = Theme.currentTheme()
        let textColor = theme.textColor()
        let labelColor = theme.labelColor()
        
        cell.backgroundColor = theme.cellBackgroundColor()
        if let cell = cell as? PrinterViewCell {
            cell.printerLabel?.textColor = textColor
            cell.printedTextLabel?.textColor = labelColor
            cell.printTimeLeftTextLabel?.textColor = labelColor
            cell.printerStatusTextLabel?.textColor = labelColor
            cell.printerStatusLabel?.textColor = textColor
            cell.progressLabel?.textColor = textColor
            cell.printTimeLeftLabel?.textColor = textColor
            cell.layerTextLabel?.textColor = labelColor
            cell.layerLabel?.textColor = textColor
        }
    }
        
    // MARK: Connection notifications
    
    func refreshItem(row: Int) {
        DispatchQueue.main.async {
            // Check that list of printers is still in sync with what is being displayed
            if self.printers.count > row {
                self.collectionView.reloadItems(at: [IndexPath(row: row, section: 0)])
            }
        }
    }

}
