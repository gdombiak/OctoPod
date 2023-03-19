import WidgetKit
import SwiftUI
import Intents
import CoreData

struct Provider: IntentTimelineProvider {
    
    let persistentContainer: SharedPersistentContainer
    let printerManager: PrinterManager
    
    init() {
        persistentContainer = SharedPersistentContainer(name: "OctoPod")
        persistentContainer.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                NSLog("Unresolved error \(error), \(error.userInfo)")
            }
        })

        printerManager = PrinterManager(managedObjectContext: persistentContainer.viewContext, persistentContainer: persistentContainer)
    }
    
    
    func placeholder(in context: Context) -> SimpleEntry {
        let configuration = WidgetConfigurationIntent()
        configuration.printer = WidgetPrinter(identifier: "MK3", display: "MK3")
        configuration.printer?.name = "MK3"

        let jobService = PrintJobDataService(name: "MK3", hostname: "", apiKey: "", username: nil, password: nil, preemptive: false)
        jobService.printerStatus = "Printing"
        jobService.progress = 28.0
        jobService.printEstimatedCompletion = "9:30 PM"
        
        let cameraService = CameraService(cameraURL: "", cameraOrientation: 1, username: nil, password: nil, preemptiveAuth: false)
        cameraService.image = UIImage(named: "Image")

        return SimpleEntry(date: Date(), configuration: configuration, printJobDataService: jobService, cameraService: cameraService)
    }
    
    func getSnapshot(for configuration: WidgetConfigurationIntent, in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        var lockScreenWidget = false
        if #available(iOSApplicationExtension 16.0, *) {
            lockScreenWidget = context.family == .accessoryRectangular || context.family == .accessoryCircular
        }

        if lockScreenWidget {
            // Lock Screen widget shows print job information of DEFAULT printer
            if let widgetPrinter = printerManager.getDefaultPrinter() {
                let service = PrintJobDataService(name: widgetPrinter.name, hostname: widgetPrinter.hostname, apiKey: widgetPrinter.apiKey, username: widgetPrinter.username, password: widgetPrinter.password, preemptive: widgetPrinter.preemptiveAuthentication())

                let entry = SimpleEntry(date: Date(), configuration: configuration, printJobDataService: service, cameraService: nil)
                // Fetch update data and once data execute completion block
                service.updateData {
                    completion(entry)
                }
            } else {
                // No default printer was found so return empty print job data
                let entry = SimpleEntry(date: Date(), configuration: configuration, printJobDataService: nil, cameraService: nil)
                completion(entry)
            }
        } else {
            // Regular widgets need to be configured by user to specify which printer to render
            if let widgetPrinter = configuration.printer, let printerName = widgetPrinter.name, let hostname = widgetPrinter.hostname, let apiKey = widgetPrinter.apiKey {
                var preemptive: Bool = false
                if let preemptiveAuth = widgetPrinter.preemptiveAuth {
                    preemptive = preemptiveAuth == 1
                }
                let service = PrintJobDataService(name: printerName, hostname: hostname, apiKey: apiKey, username: widgetPrinter.username, password: widgetPrinter.password, preemptive: preemptive)
                var cameraService: CameraService?
                if let widgetCamera = configuration.camera, let cameraURL = widgetCamera.cameraURL, let cameraOrientation = widgetCamera.cameraOrientation {
                    cameraService = CameraService(cameraURL: cameraURL, cameraOrientation: Int(truncating: cameraOrientation), username: widgetPrinter.username, password: widgetPrinter.password, preemptiveAuth: preemptive)
                }
                let entry = SimpleEntry(date: Date(), configuration: configuration, printJobDataService: service, cameraService: cameraService)
                // Fetch update data and once data execute completion block
                service.updateData {
                    if cameraService != nil && context.family != .systemSmall {
                        // Fetch image only if widget is medium and has been configured properly
                        cameraService?.renderImage(completion: {
                            completion(entry)
                        })
                    } else {
                        completion(entry)
                    }
                }
            } else {
                // Intent has not been configured so return empty print job data
                let entry = SimpleEntry(date: Date(), configuration: configuration, printJobDataService: nil, cameraService: nil)
                completion(entry)
            }

        }
    }
    
    func getTimeline(for configuration: WidgetConfigurationIntent, in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {

        getSnapshot(for: configuration, in: context) { (entry: SimpleEntry) in
            let entries: [SimpleEntry] = [entry]
            
            var isPrinting: Bool = false
            if let printJobService = entry.printJobDataService {
                isPrinting = printJobService.isPrinting()
            }

            // Calcuate refresh date
            let calendar = Calendar.current
            let refreshDate = isPrinting ? calendar.date(byAdding: .minute, value: 5, to: Date())! : calendar.date(byAdding: .hour, value: 1, to: Date())!

            let timeline = Timeline(entries: entries, policy: .after(refreshDate))
            completion(timeline)
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: WidgetConfigurationIntent
    
    let printJobDataService: PrintJobDataService?
    let cameraService: CameraService?
    
}

struct OctoPodWidget14EntryView : View {
    var entry: Provider.Entry
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.widgetFamily) var family
    
    @ViewBuilder
    var body: some View {
        ZStack {
            switch self.entry.configuration.theme {
            case Theme.light:
                Color(.sRGB, red: 230 / 255, green: 230 / 255, blue: 230 / 255, opacity: 0.75)
                    .edgesIgnoringSafeArea(.all)
            case Theme.dark:
                Color(.sRGB, red: 89 / 255, green: 89 / 255, blue: 89 / 255, opacity: 0.75)
                    .edgesIgnoringSafeArea(.all)
            case Theme.system:
                if colorScheme == .dark {
                    Color(.sRGB, red: 89 / 255, green: 89 / 255, blue: 89 / 255, opacity: 0.75)
                        .edgesIgnoringSafeArea(.all)
                } else {
                    Color(.sRGB, red: 230 / 255, green: 230 / 255, blue: 230 / 255, opacity: 0.75)
                        .edgesIgnoringSafeArea(.all)
                }
            default:
                Color(.sRGB, red: 154 / 255, green: 211 / 255, blue: 110 / 255, opacity: 0.75)
                    .edgesIgnoringSafeArea(.all)
            }
            
            if let printerName = entry.configuration.printer?.name, let urlSafePrinter = printerName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {

                switch family {
                case .systemSmall:
                    
                    VStack(spacing: 10) {
                        JobDetailsView(printerName: printerName, entry: entry)
                    }.widgetURL(URL(string: "octopod://\(urlSafePrinter)")!)
                    
                case .systemMedium:
                    HStack() {
                        VStack(spacing: 10) {
                            JobDetailsView(printerName: printerName, entry: entry)
                        }.widgetURL(URL(string: "octopod://\(urlSafePrinter)")!)
                        if let cameraService = entry.cameraService {
                            if let image = cameraService.image {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                            } else {
                                // Failed to fetch image so display placeholder
                                // In the future we could add a text with the reason of the failure
                                Image("Image")
                                    .resizable()
                            }
                        } else {
                            // No camera was configured in the widget
                            VStack {
                                Image("Image")
                                    .resizable()
                                Text("Configure widget")
                            }
                        }
                    }
                    .padding(10.0)
                case .accessoryCircular:
                    if let progress = entry.printJobDataService?.progress {
                        ProgressBarView(progress: .constant(progress), color: .constant(.white))
                            .frame(width: 60.0, height: 60.0)
                    } else {
                        Image("OctoPod")
                            .resizable()
                            .scaledToFit()
                    }
                case .accessoryRectangular:
                    LockedRectangularView(entry: entry)
                default:
                    LargetDetailsView(printerName: printerName, entry: entry)
                        .padding(10.0)
                        .widgetURL(URL(string: "octopod://\(urlSafePrinter)")!)
                }
            } else {
                // No printer has been selected so ask to configure widget
                Text("Configure widget")
            }
        }
    }
}

@available(iOSApplicationExtension 14.0, *)
@main
struct OctoPodWidgets: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        OctoPodWidget14()
        DashboardWidget()
        
        if #available(iOS 16.1, *) {
            LiveActivityWidget()
        }
    }
}

struct OctoPodWidget14: Widget {
    let kind: String = "OctoPodWidget14"
    
    func families() -> Array<WidgetFamily> {
        if #available(iOSApplicationExtension 16.0, *) {
            return [.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryCircular]
        } else {
            return [.systemSmall, .systemMedium, .systemLarge]
        }
    }
    
    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: WidgetConfigurationIntent.self, provider: Provider()) { entry in
            OctoPodWidget14EntryView(entry: entry)
        }
        .configurationDisplayName("OctoPod")
        .description(NSLocalizedString("Monitor and control your 3d printer via OctoPod", comment: ""))
        .supportedFamilies(families())
    }
}

@available(iOSApplicationExtension 13.0, *)
struct OctoPodWidget14_Previews: PreviewProvider {
    static var intent: WidgetConfigurationIntent = {
        let configuration = WidgetConfigurationIntent()
        configuration.printer = WidgetPrinter(identifier: "MK3", display: "MK3")
        configuration.printer?.name = "MK3"
        return configuration
    }()

    static var jobService: PrintJobDataService = {
        let jobService = PrintJobDataService(name: "MK3", hostname: "", apiKey: "", username: nil, password: nil, preemptive: false)
        jobService.printerStatus = "Printing"
        jobService.progress = 28.0
        jobService.printEstimatedCompletion = "9:30 PM"
        return jobService
    }()
    
    static var cameraService: CameraService = {
        let cameraService = CameraService(cameraURL: "", cameraOrientation: 1, username: nil, password: nil, preemptiveAuth: false)
        cameraService.image = UIImage(named: "Image")
        return cameraService
    }()

    static var previews: some View {
        Group {
            OctoPodWidget14EntryView(entry: SimpleEntry(date: Date(), configuration: intent, printJobDataService: jobService, cameraService: cameraService))
                .previewContext(WidgetPreviewContext(family: .systemSmall))

            OctoPodWidget14EntryView(entry: SimpleEntry(date: Date(), configuration: intent, printJobDataService: jobService, cameraService: cameraService))
                .previewContext(WidgetPreviewContext(family: .systemMedium))

            OctoPodWidget14EntryView(entry: SimpleEntry(date: Date(), configuration: intent, printJobDataService: jobService, cameraService: cameraService))
                .previewContext(WidgetPreviewContext(family: .systemLarge))

            if #available(iOSApplicationExtension 16.0, *) {
                OctoPodWidget14EntryView(entry: SimpleEntry(date: Date(), configuration: intent, printJobDataService: jobService, cameraService: cameraService))
                    .previewContext(WidgetPreviewContext(family: .accessoryCircular))

                OctoPodWidget14EntryView(entry: SimpleEntry(date: Date(), configuration: intent, printJobDataService: jobService, cameraService: cameraService))
                    .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
            }
        }
    }
}
