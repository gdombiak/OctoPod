import ClockKit
import WatchKit

class ComplicationController: NSObject, CLKComplicationDataSource, PanelManagerDelegate {
    
    private let COMPLICATION_CONTENT_TYPE_KEY = "COMPLICATION_CONTENT_TYPE"
    
    /// Select what type of content should be displayed in complication
    fileprivate enum ContentType: Int {
        /// Display priner name
        case defaultText
        /// When Palette2 info is available, display last ping value. Fallback to printer name
        case palette2LastPing
        /// When Palette2 info is available, display last ping variance. Fallback to printer name
        case palette2LastVariation
        /// When Palette2 info is available, display max ping variance. Fallback to printer name
        case palette2MaxVariation
    }
    
    /// Time when the next background task should run
    private var scheduledBackgroundTask: Date?
    
    private var complicationContentType: ContentType = .defaultText

    private var currentPrinterName: String!
    private var currentPrinterState: String!
    private var completion: Double!
    private var palette2LastPing: String?
    private var palette2LastVariation: String?
    private var palette2MaxVariation: String?
    
    private let printColor = UIColor(red: 48/255, green: 140/255, blue: 140/255, alpha: 1.0)
    private let notPrintColor = UIColor(red: 0/255, green: 111/255, blue: 234/255, alpha: 1.0)
    
    override init() {
        super.init()
        currentPrinterName = NSLocalizedString("No printer", comment: "No printer has been selected")
        currentPrinterState = NSLocalizedString("Unknown", comment: "")
        completion = 0
        
        // Listen to changes to panel information
        PanelManager.instance.delegates.append(self)
        
        // Save new value as a setting
        let savedContentType = UserDefaults.standard.integer(forKey: COMPLICATION_CONTENT_TYPE_KEY)
        if let restoredContentType = ContentType(rawValue: savedContentType) {
            complicationContentType = restoredContentType
        }
    }
    
    // MARK: - Timeline Configuration
    
    func getSupportedTimeTravelDirections(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimeTravelDirections) -> Void) {
        handler([])
    }
    
    // MARK: - Timeline Population
    
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        // Call the handler with the current timeline entry

//        let isPrinting = currentPrinterState == "Printing"
        let hasCompletion = completion != nil && completion! > 0

        switch complication.family {
        case .modularSmall:
            let image: UIImage = UIImage(named: hasCompletion ? "Printing" : "Not Printing")!
//            let image: UIImage = UIImage(named: "Complication/Modular")!
            let template = CLKComplicationTemplateModularSmallRingImage()
            template.imageProvider = CLKImageProvider(onePieceImage: image)
            template.fillFraction = hasCompletion ? Float(completion / 100) : 0.0
            let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
            handler(entry)
        case .modularLarge:
            let template = CLKComplicationTemplateModularLargeStandardBody()
            template.headerTextProvider = CLKSimpleTextProvider(text: currentPrinterName)
            template.body1TextProvider = CLKSimpleTextProvider(text: currentPrinterState)
            let completionText: String = hasCompletion ? "\(String(format: "%.1f", completion!))%" : ""
            template.body2TextProvider = CLKSimpleTextProvider(text: complicationText(initial: completionText, replace: false))
            let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
            handler(entry)

        case .circularSmall:
            let template = CLKComplicationTemplateCircularSmallRingImage()
            let image: UIImage = UIImage(named: hasCompletion ? "Printing" : "Not Printing")!
            template.imageProvider = CLKImageProvider(onePieceImage: image)
            template.fillFraction = hasCompletion ? Float(completion / 100) : 0.0
            let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
            handler(entry)

        case .extraLarge:
            let template = CLKComplicationTemplateExtraLargeRingText()
            template.textProvider = CLKSimpleTextProvider(text: complicationText(initial: currentPrinterName, replace: true))
            template.fillFraction = hasCompletion ? Float(completion / 100) : 0.0
            template.ringStyle = .closed
            let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
            handler(entry)

        case .utilitarianSmall:
            let template = CLKComplicationTemplateUtilitarianSmallRingImage()
            let image: UIImage = UIImage(named: hasCompletion ? "Printing" : "Not Printing")!
            template.imageProvider = CLKImageProvider(onePieceImage: image)
            template.fillFraction = hasCompletion ? Float(completion / 100) : 0.0
            template.ringStyle = .closed
            let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
            handler(entry)
            
        case .utilitarianSmallFlat:
            let template = CLKComplicationTemplateUtilitarianSmallFlat()
            let image: UIImage = UIImage(named: hasCompletion ? "Printing" : "Not Printing")!
            template.imageProvider = CLKImageProvider(onePieceImage: image)
            template.textProvider = CLKSimpleTextProvider(text: hasCompletion ? "\(String(format: "%.1f", completion!))%" : "")
            let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
            handler(entry)

        case .graphicCorner:
            if hasCompletion {
                let template = CLKComplicationTemplateGraphicCornerGaugeText()
                template.outerTextProvider = CLKSimpleTextProvider(text: complicationText(initial: currentPrinterName, replace: true))
                template.gaugeProvider = CLKSimpleGaugeProvider(style: .fill, gaugeColor: .cyan, fillFraction: Float(completion / 100))
                let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
                handler(entry)
            } else {
                let template = CLKComplicationTemplateGraphicCornerStackText()
                template.outerTextProvider = CLKSimpleTextProvider(text: complicationText(initial: currentPrinterName, replace: true))
                let innerTextProvider = CLKSimpleTextProvider(text: currentPrinterState)
                innerTextProvider.tintColor = notPrintColor
                template.innerTextProvider = innerTextProvider
                let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
                handler(entry)
            }
        case .graphicCircular:
            let template = CLKComplicationTemplateGraphicCircularClosedGaugeImage()
            let image: UIImage = UIImage(named: hasCompletion ? "Printing" : "Not Printing")!
            template.imageProvider = CLKFullColorImageProvider(fullColorImage: image)
            template.gaugeProvider = CLKSimpleGaugeProvider(style: .fill, gaugeColor: .cyan, fillFraction: hasCompletion ? Float(completion / 100) : CLKSimpleGaugeProviderFillFractionEmpty)
            let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
            handler(entry)
        case .graphicRectangular:
            let template = CLKComplicationTemplateGraphicRectangularTextGauge()
            template.headerTextProvider = CLKSimpleTextProvider(text: currentPrinterName)
            template.body1TextProvider = CLKSimpleTextProvider(text: complicationText(initial: currentPrinterState, replace: false))
            template.gaugeProvider = CLKSimpleGaugeProvider(style: .fill, gaugeColor: .cyan, fillFraction: hasCompletion ? Float(completion / 100) : CLKSimpleGaugeProviderFillFractionEmpty)
            let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
            handler(entry)

        default:
            handler(nil)
        }
    }
    
    // MARK: - Placeholder Templates
    
    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        // This method will be called once per supported complication, and the results will be cached

        switch complication.family {
        case .modularSmall:
//            let image: UIImage = UIImage(named: "Complication/Modular")!
            let image: UIImage = UIImage(named: "Printing")!
            let template = CLKComplicationTemplateModularSmallRingImage()
            template.imageProvider = CLKImageProvider(onePieceImage: image)
            template.fillFraction = 0.4
            handler(template)
        case .modularLarge:
            let template = CLKComplicationTemplateModularLargeStandardBody()
            template.headerTextProvider = CLKSimpleTextProvider(text: NSLocalizedString("MK3", comment: ""))
            template.body1TextProvider = CLKSimpleTextProvider(text: NSLocalizedString("Printing", comment: ""))
            template.body2TextProvider = CLKSimpleTextProvider(text: "50.3%")
            handler(template)

        case .circularSmall:
            let image: UIImage = UIImage(named: "Printing")!
//            let image: UIImage = UIImage(named: "Complication/Circular")!
            let template = CLKComplicationTemplateCircularSmallRingImage()
            template.imageProvider = CLKImageProvider(onePieceImage: image)
            template.fillFraction = 0.4
            handler(template)
            
        case .extraLarge:
            let template = CLKComplicationTemplateExtraLargeRingText()
            template.textProvider = CLKSimpleTextProvider(text: NSLocalizedString("MK3", comment: ""))
            template.fillFraction = 0.4
            template.ringStyle = .closed
            handler(template)

        case .utilitarianSmall:
            let template = CLKComplicationTemplateUtilitarianSmallRingImage()
            let image: UIImage = UIImage(named: "Printing")!
            template.imageProvider = CLKImageProvider(onePieceImage: image)
            template.fillFraction = 0.4
            template.ringStyle = .closed
            handler(template)

        case .utilitarianSmallFlat:
            let template = CLKComplicationTemplateUtilitarianSmallFlat()
            let image: UIImage = UIImage(named: "Printing")!
            template.imageProvider = CLKImageProvider(onePieceImage: image)
            template.textProvider = CLKSimpleTextProvider(text: "50.3%")
            handler(template)

        case .graphicCorner:
            let template = CLKComplicationTemplateGraphicCornerGaugeText()
            template.outerTextProvider = CLKSimpleTextProvider(text: NSLocalizedString("MK3", comment: ""))
            template.gaugeProvider = CLKSimpleGaugeProvider(style: .fill, gaugeColor: .cyan, fillFraction: 0.4)
            handler(template)
        case .graphicCircular:
            let image: UIImage = UIImage(named: "Printing")!
//            let image: UIImage = UIImage(named: "Complication/Graphic Circular")!
            let template = CLKComplicationTemplateGraphicCircularClosedGaugeImage()
            template.imageProvider = CLKFullColorImageProvider(fullColorImage: image)
            template.gaugeProvider = CLKSimpleGaugeProvider(style: .fill, gaugeColor: .cyan, fillFraction: 0.4)
            handler(template)
        case .graphicRectangular:
            let template = CLKComplicationTemplateGraphicRectangularTextGauge()
            template.headerTextProvider = CLKSimpleTextProvider(text: NSLocalizedString("MK3", comment: ""))
            template.body1TextProvider = CLKSimpleTextProvider(text: NSLocalizedString("Printing", comment: ""))
            template.gaugeProvider = CLKSimpleGaugeProvider(style: .fill, gaugeColor: .cyan, fillFraction: 0.4)
            handler(template)

        default:
            handler(nil)
        }
    }
    
    // MARK: - PanelManagerDelegate
    
    func panelInfoUpdate(printerName: String, panelInfo: [String : Any]) {
        if let error = panelInfo["error"] as? String {
            NSLog("Not updating complication since there was an error. Error: \(error)")
        } else if let state = panelInfo["state"] as? String {
            var pushState = state
            if state == "Printing from SD" {
                pushState = "Printing"
            } else if state.starts(with: "Offline (Error:") {
                pushState = "Offline"
            }
            if pushState == "Offline" || pushState == "Operational" || pushState == "Printing" || pushState == "Paused" {
                let completion = panelInfo["completion"] as? Double ?? 0
                let palette2LastPing: String? = panelInfo["palette2LastPing"] as? String
                let palette2LastVariation: String? = panelInfo["palette2LastVariation"] as? String
                let palette2MaxVariation: String? = panelInfo["palette2MaxVariation"] as? String
                pushUpdateToComplications(printerName: printerName, state: pushState, completion: completion, palette2LastPing: palette2LastPing, palette2LastVariation: palette2LastVariation, palette2MaxVariation: palette2MaxVariation)
            }
        }
    }
    
    func updateComplications(printerName: String, printerState: String, completion: Double, palette2LastPing: String?, palette2LastVariation: String?, palette2MaxVariation: String?) {
        pushUpdateToComplications(printerName: printerName, state: printerState, completion: completion, palette2LastPing: palette2LastPing, palette2LastVariation: palette2LastVariation, palette2MaxVariation: palette2MaxVariation)
    }
    
    func updateComplicationsContentType(contentType: String) {
        if contentType == "defaultText" {
            complicationContentType = .defaultText
        } else if contentType == "palette2LastPing" {
            complicationContentType = .palette2LastPing
        } else if contentType == "palette2LastVariation" {
            complicationContentType = .palette2LastVariation
        } else if contentType == "palette2MaxVariation" {
            complicationContentType = .palette2MaxVariation
        }
        // Save new value as a setting
        UserDefaults.standard.set(complicationContentType.rawValue, forKey: COMPLICATION_CONTENT_TYPE_KEY)
    }

    // MARK: - Private operations
    
    fileprivate func pushUpdateToComplications(printerName: String, state: String, completion: Double, palette2LastPing: String?, palette2LastVariation: String?, palette2MaxVariation: String?) {
        // TODO: - Future release might let users configure when they sleep so we refresh at a slower
        // rate when they do not use the app. There is a limit of 50 complication updates per day. Long
        // prints > 12.5 hours will exceed the 50 complications upates per day :(

        if completion > 0 && completion < 100 {
            // Schedule next background refresh in 15 minutes if we are printing
            scheduleNextBackgroundRefresh(minutes: 15)
        } else {
            // Schedule next background refresh in 60 minutes if we are NOT printing to save battery
            // If print started before next background refresh then complication will be updated if
            // 1. OctoPrint plugin is installed and a print started (iOS app will receive notification and ask Apple Watch
            // to refresh complication) or 2. iOS app did background refresh and a print is running and there is no
            // OctoPrint plugin installed or 3. user opened Apple Watch app while print is running
            scheduleNextBackgroundRefresh(minutes: 60)
        }
        if currentPrinterName != printerName || currentPrinterState != state  || self.completion != completion || self.palette2LastPing != palette2LastPing || self.palette2LastVariation != palette2LastVariation || self.palette2MaxVariation != palette2MaxVariation {
            // Update locally stored information
            currentPrinterName = printerName
            currentPrinterState = state
            self.completion = completion
            self.palette2LastPing = palette2LastPing
            self.palette2LastVariation = palette2LastVariation
            self.palette2MaxVariation = palette2MaxVariation
            
            // Update complications since state has changed
            let complicationServer = CLKComplicationServer.sharedInstance()
            if let complications = complicationServer.activeComplications {
                for complication in complications {
                    complicationServer.reloadTimeline(for: complication)
                }
            }
        }
    }
    
    fileprivate func complicationText(initial: String, replace: Bool) -> String {
        switch complicationContentType {
        case .defaultText:
            return initial
        case .palette2LastPing:
            if let replacement = palette2LastPing, replacement != "" {
                return replace ? replacement : "\(initial) - \(replacement)"
            }
        case .palette2LastVariation:
            if let replacement = palette2LastVariation, replacement != ""  {
                return replace ? replacement : "\(initial) - \(replacement)"
            }
        case .palette2MaxVariation:
            if let replacement = palette2MaxVariation, replacement != ""  {
                return replace ? replacement : "\(initial) - \(replacement)"
            }
        }
        return initial
    }

    // MARK: - Background refresh task
    
    fileprivate func scheduleNextBackgroundRefresh(minutes: Int) {
        if scheduledBackgroundTask == nil || scheduledBackgroundTask! < Date() {
            // Schedule a background refresh task to run in 20 minutes
            scheduledBackgroundTask = Date(timeIntervalSinceNow: Double(minutes * 60))

            WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: scheduledBackgroundTask!, userInfo: nil) { (error: Error?) in
                if let error = error {
                    self.scheduledBackgroundTask = nil
                    NSLog("Error schedulding background refresh task: \(error.localizedDescription)")
                    // TODO: There is no retry logic if scheduling task failed
                } else {
                    NSLog("ComplicationController: Next background update at %@", "\(self.scheduledBackgroundTask!)")
                }
            }
        }
    }
}
