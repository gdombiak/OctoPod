import ClockKit


class ComplicationController: NSObject, CLKComplicationDataSource, PanelManagerDelegate {
    
    private var currentPrinterName: String!
    private var currentPrinterState: String!
    
    override init() {
        super.init()
        currentPrinterName = NSLocalizedString("No printer", comment: "No printer has been selected")
        currentPrinterState = NSLocalizedString("Unknown", comment: "")
        
        // Listen to changes to panel information
        PanelManager.instance.delegates.append(self)
    }
    
    // MARK: - Timeline Configuration
    
    func getSupportedTimeTravelDirections(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimeTravelDirections) -> Void) {
        handler([])
    }
    
    // MARK: - Timeline Population
    
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        // Call the handler with the current timeline entry

        let isPrinting = currentPrinterState == "Printing"

        switch complication.family {
        case .modularSmall:
            let image: UIImage = UIImage(named: "Complication/Modular")!
            let template = CLKComplicationTemplateModularSmallSimpleImage()
            template.imageProvider = CLKImageProvider(onePieceImage: image)
            template.imageProvider.tintColor = isPrinting ? UIColor(red: 48/255, green: 140/255, blue: 140/255, alpha: 1.0) : UIColor(red: 0/255, green: 111/255, blue: 234/255, alpha: 1.0)
            let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
            handler(entry)
        case .modularLarge:
            let template = CLKComplicationTemplateModularLargeStandardBody()
            template.headerTextProvider = CLKSimpleTextProvider(text: currentPrinterName)
            template.body1TextProvider = CLKSimpleTextProvider(text: currentPrinterState)
            let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
            handler(entry)

        case .circularSmall:
            // WatchOS is not changing tint so we could only change icon but we have only one icon so do nothing
            handler(nil)

        case .extraLarge:
            let template = CLKComplicationTemplateExtraLargeStackText()
            template.line1TextProvider = CLKSimpleTextProvider(text: currentPrinterName)
            template.line2TextProvider = CLKSimpleTextProvider(text: currentPrinterState)
            let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
            handler(entry)

        case .graphicCircular:
            let image: UIImage = UIImage(named: isPrinting ? "Movement Frog" : "No movement Frog")!
            let template = CLKComplicationTemplateGraphicCircularImage()
            template.imageProvider = CLKFullColorImageProvider(fullColorImage: image)
            let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
            handler(entry)
        case .graphicRectangular:
            let template = CLKComplicationTemplateGraphicRectangularStandardBody()
            template.headerTextProvider = CLKSimpleTextProvider(text: currentPrinterName)
            template.body1TextProvider = CLKSimpleTextProvider(text: currentPrinterState)
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
            let image: UIImage = UIImage(named: "Complication/Modular")!
            let template = CLKComplicationTemplateModularSmallSimpleImage()
            template.imageProvider = CLKImageProvider(onePieceImage: image)
            handler(template)
        case .modularLarge:
            let template = CLKComplicationTemplateModularLargeStandardBody()
            template.headerTextProvider = CLKSimpleTextProvider(text: NSLocalizedString("MK3", comment: ""))
            template.body1TextProvider = CLKSimpleTextProvider(text: NSLocalizedString("Printing", comment: ""))
            handler(template)

        case .circularSmall:
            let image: UIImage = UIImage(named: "Complication/Circular")!
            let template = CLKComplicationTemplateCircularSmallSimpleImage()
            template.imageProvider = CLKImageProvider(onePieceImage: image)
            handler(template)
            
        case .extraLarge:
            let template = CLKComplicationTemplateExtraLargeStackText()
            template.line1TextProvider = CLKSimpleTextProvider(text: NSLocalizedString("MK3", comment: ""))
            template.line2TextProvider = CLKSimpleTextProvider(text: NSLocalizedString("Paused", comment: ""))
            handler(template)

        case .graphicCircular:
            let image: UIImage = UIImage(named: "Complication/Graphic Circular")!
            let template = CLKComplicationTemplateGraphicCircularImage()
            template.imageProvider = CLKFullColorImageProvider(fullColorImage: image)
            handler(template)
        case .graphicRectangular:
            let template = CLKComplicationTemplateGraphicRectangularStandardBody()
            template.headerTextProvider = CLKSimpleTextProvider(text: NSLocalizedString("MK3", comment: ""))
            template.body1TextProvider = CLKSimpleTextProvider(text: NSLocalizedString("Printing", comment: ""))
            handler(template)

        default:
            handler(nil)
        }
    }
    
    // MARK: - PanelManagerDelegate
    
    // Notification that new panel information has been received
    func panelInfoUpdate(printerName: String, panelInfo: [String : Any]) {
        if let error = panelInfo["error"] as? String {
            NSLog("Not updating complication since there was an error. Error: \(error)")
        } else if let state = panelInfo["state"] as? String {
            pushUpdateToComplications(printerName: printerName, state: state)
        }
    }
    
    // Notification that we need to update complications. Originated from iOS App
    func updateComplications(printerName: String, printerState: String) {
        pushUpdateToComplications(printerName: printerName, state: printerState)
    }
    
    // MARK: - Private operations
    
    fileprivate func pushUpdateToComplications(printerName: String, state: String) {
        if currentPrinterName != printerName || currentPrinterState != state {
            // Update locally stored information
            currentPrinterName = printerName
            currentPrinterState = state
            
            // Update complications since state has changed
            let complicationServer = CLKComplicationServer.sharedInstance()
            if let complications = complicationServer.activeComplications {
                for complication in complications {
                    complicationServer.reloadTimeline(for: complication)
                }
            }
        }
    }
}
