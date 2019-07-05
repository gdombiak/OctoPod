import UIKit
import Charts

class TempHistoryViewController: UIViewController, SubpanelViewController {

    let octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    let appConfiguration: AppConfiguration = { return (UIApplication.shared.delegate as! AppDelegate).appConfiguration }()

    @IBOutlet weak var lineChartView: LineChartView!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // If running in small screen then reduce height so page control (dots)
        // do not overlap the chart letters
        let devicePortrait = UIApplication.shared.statusBarOrientation.isPortrait
        let screenHeight = devicePortrait ? UIScreen.main.bounds.height : UIScreen.main.bounds.width
        if screenHeight <= 568 {
            // iPhone 5, 5s, 5c, SE
            bottomConstraint.constant = -15
        } else {
            // Bigger screens
            bottomConstraint.constant = -12
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        let theme = Theme.currentTheme()
        let labelColor = theme.labelColor()
        view.backgroundColor = theme.backgroundColor()
        lineChartView.backgroundColor = theme.backgroundColor()
        lineChartView.xAxis.labelTextColor = labelColor
        lineChartView.leftAxis.labelTextColor = labelColor
        lineChartView.rightAxis.labelTextColor = labelColor
        lineChartView.chartDescription?.textColor = labelColor
        lineChartView.legend.textColor = labelColor
        lineChartView.noDataTextColor = labelColor

        lineChartView.chartDescription?.font = .systemFont(ofSize: 10.0)
        lineChartView.chartDescription?.text = NSLocalizedString("Temperature", comment: "Temperature")
        lineChartView.noDataText = NSLocalizedString("No temperature history", comment: "No temperature history")
        
        lineChartView.xAxis.axisMaximum = 0
        
        lineChartView.xAxis.granularityEnabled = true
        lineChartView.leftAxis.granularityEnabled = true
        lineChartView.rightAxis.granularityEnabled = true
        lineChartView.xAxis.granularity = 0.5
        lineChartView.leftAxis.granularity = 0.5
        lineChartView.rightAxis.granularity = 0.5
        
        // Control whether users can do zoom in/out
        lineChartView.isUserInteractionEnabled = !appConfiguration.tempChartZoomDisabled()
        
        // Disable highlighting (the vertical and horizontal yellow lines)
        lineChartView.highlightPerTapEnabled = false
        lineChartView.highlightPerDragEnabled = false

        paintChart()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    // MARK: - SubpanelViewController
    
    func printerSelectedChanged() {
        if lineChartView == nil {
            // UI is still not ready so do not refresh yet
            return
        }
        // Refresh UI
        DispatchQueue.main.async {
            self.paintChart()
        }
    }
    
    // Notification that OctoPrint state has changed. This may include printer status information
    func currentStateUpdated(event: CurrentStateEvent) {
        if lineChartView == nil {
            // UI is still not ready so do not refresh yet
            return
        }
        DispatchQueue.main.async {
            self.paintChart()
        }
    }

    // Returns the position where this VC should appear in SubpanelsViewController's UIPageViewController
    // SubpanelsViewController's will sort subpanels by this number when being displayed
    func position() -> Int {
        return 1
    }
    
    // MARK: - Private functions
    
    fileprivate func paintChart() {
        let lineChartData = LineChartData()
        var bedActualEntries = Array<ChartDataEntry>()
        var bedTargetEntries = Array<ChartDataEntry>()
        var tool0ActualEntries = Array<ChartDataEntry>()
        var tool0TargetEntries = Array<ChartDataEntry>()
        var tool1ActualEntries = Array<ChartDataEntry>()
        var tool1TargetEntries = Array<ChartDataEntry>()
        var chamberActualEntries = Array<ChartDataEntry>()
        var chamberTargetEntries = Array<ChartDataEntry>()

        let now = Date().timeIntervalSince1970.rounded()
        var minBedActual: Double = 0, maxBedActual: Double = 0
        var minTool0Actual: Double = 0, maxTool0Actual: Double = 0
        for temp in octoprintClient.tempHistory.temps {
            if let time = temp.tempTime {
                let age = ((Double(time) - now) / 60).rounded()
                if let bedActual = temp.bedTempActual {
                    bedActualEntries.append(ChartDataEntry(x: age, y: bedActual))
                    // Calculate min and max temperatures
                    if minBedActual == 0 || bedActual < minBedActual {
                        minBedActual = bedActual
                    }
                    if maxBedActual == 0 || bedActual > maxBedActual {
                        maxBedActual = bedActual
                    }
                }
                if let bedTarget = temp.bedTempTarget {
                    bedTargetEntries.append(ChartDataEntry(x: age, y: bedTarget))
                }
                if let tool0Actual = temp.tool0TempActual {
                    tool0ActualEntries.append(ChartDataEntry(x: age, y: tool0Actual))
                    // Calculate min and max temperatures
                    if minTool0Actual == 0 || tool0Actual < minTool0Actual {
                        minTool0Actual = tool0Actual
                    }
                    if maxTool0Actual == 0 || tool0Actual > maxTool0Actual {
                        maxTool0Actual = tool0Actual
                    }
                }
                if let tool0Target = temp.tool0TempTarget {
                    tool0TargetEntries.append(ChartDataEntry(x: age, y: tool0Target))
                }
                if let tool1Actual = temp.tool1TempActual {
                    tool1ActualEntries.append(ChartDataEntry(x: age, y: tool1Actual))
                }
                if let tool1Target = temp.tool1TempTarget {
                    tool1TargetEntries.append(ChartDataEntry(x: age, y: tool1Target))
                }
                if let chamberActual = temp.chamberTempActual {
                    chamberActualEntries.append(ChartDataEntry(x: age, y: chamberActual))
                }
                if let chamberTarget = temp.chamberTempTarget {
                    chamberTargetEntries.append(ChartDataEntry(x: age, y: chamberTarget))
                }
            }
        }
        
        if !bedActualEntries.isEmpty {
            let lineColor = UIColor(red: 0/255, green: 24/255, blue: 250/255, alpha: 1.0)
            let line = createLine(values: bedActualEntries, label: NSLocalizedString("Actual Bed", comment: ""), lineColor: lineColor)
            lineChartData.addDataSet(line)
        }
        if !bedTargetEntries.isEmpty {
            let lineColor = UIColor(red: 121/255, green: 130/255, blue: 251/255, alpha: 1.0)
            let line = createLine(values: bedTargetEntries, label: NSLocalizedString("Target Bed", comment: ""), lineColor: lineColor)
            lineChartData.addDataSet(line)
        }
        
        if !tool0ActualEntries.isEmpty {
            let lineColor = UIColor(red: 255/255, green: 0/255, blue: 20/255, alpha: 1.0)
            let line = createLine(values: tool0ActualEntries, label: NSLocalizedString("Actual Extruder", comment: ""), lineColor: lineColor)
            lineChartData.addDataSet(line)
        }
        if !tool0TargetEntries.isEmpty {
            let lineColor = UIColor(red: 255/255, green: 125/255, blue: 130/255, alpha: 1.0)
            let line = createLine(values: tool0TargetEntries, label: NSLocalizedString("Target Extruder", comment: ""), lineColor: lineColor)
            lineChartData.addDataSet(line)
        }
        
        if !tool1ActualEntries.isEmpty {
            let lineColor = UIColor(red: 9/255, green: 102/255, blue: 26/255, alpha: 1.0)
            let line = createLine(values: tool1ActualEntries, label: NSLocalizedString("Actual Extruder 2", comment: ""), lineColor: lineColor)
            lineChartData.addDataSet(line)
        }
        if !tool1TargetEntries.isEmpty {
            let lineColor = UIColor(red: 82/255, green: 170/255, blue: 90/255, alpha: 1.0)
            let line = createLine(values: tool1TargetEntries, label: NSLocalizedString("Target Extruder 2", comment: ""), lineColor: lineColor)
            lineChartData.addDataSet(line)
        }
        
        if !chamberActualEntries.isEmpty {
            let lineColor = UIColor(red: 204/255, green: 153/255, blue: 0/255, alpha: 1.0)
            let line = createLine(values: chamberActualEntries, label: NSLocalizedString("Actual Chamber", comment: ""), lineColor: lineColor)
            lineChartData.addDataSet(line)
        }
        if !chamberTargetEntries.isEmpty {
            let lineColor = UIColor(red: 204/255, green: 204/255, blue: 0/255, alpha: 1.0)
            let line = createLine(values: chamberTargetEntries, label: NSLocalizedString("Target Chamber", comment: ""), lineColor: lineColor)
            lineChartData.addDataSet(line)
        }

        if !lineChartData.dataSets.isEmpty {
            // Add data to chart view. This will cause an update in the UI
            lineChartView.data = lineChartData
           
            // Display temp variance
            lineChartView.chartDescription?.text = NSLocalizedString("Extruder Variance", comment: "") + ": \(String(format: "%0.*f", 1, (maxTool0Actual - minTool0Actual))) - " + NSLocalizedString("Bed Variance", comment: "") + ": \(String(format: "%0.*f", 1, (maxBedActual - minBedActual)))"
        } else {
            lineChartView.data = nil
            lineChartView.chartDescription?.text = NSLocalizedString("Temperature", comment: "Temperature")
        }
    }
    
    fileprivate func createLine(values: [ChartDataEntry], label: String, lineColor: UIColor) -> LineChartDataSet {
        let line = LineChartDataSet(entries: values, label: label)
        line.colors = [lineColor]
        line.drawCirclesEnabled = false
        line.drawValuesEnabled = false
        return line
    }
}
