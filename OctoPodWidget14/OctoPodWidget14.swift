import WidgetKit
import SwiftUI
import Intents

struct Provider: IntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        let configuration = WidgetConfigurationIntent()
        configuration.printer = WidgetPrinter(identifier: "MK3", display: "MK3")
        configuration.printer?.name = "MK3"

        let jobService = PrintJobDataService(hostname: "", apiKey: "", username: nil, password: nil)
        jobService.printerStatus = "Printing"
        jobService.progress = 28.0
        jobService.printEstimatedCompletion = "9:30 PM"

        return SimpleEntry(date: Date(), configuration: configuration, printJobDataService: jobService, cameraService: nil)
    }
    
    func getSnapshot(for configuration: WidgetConfigurationIntent, in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        if let widgetPrinter = configuration.printer, let hostname = widgetPrinter.hostname, let apiKey = widgetPrinter.apiKey {
            let service = PrintJobDataService(hostname: hostname, apiKey: apiKey, username: widgetPrinter.username, password: widgetPrinter.password)
            var cameraService: CameraService?
            if let widgetCamera = configuration.camera, let cameraURL = widgetCamera.cameraURL, let cameraOrientation = widgetCamera.cameraOrientation {
                cameraService = CameraService(cameraURL: cameraURL, cameraOrientation: Int(truncating: cameraOrientation), username: widgetPrinter.username, password: widgetPrinter.password)
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
    
    @Environment(\.widgetFamily) var family
    
    @ViewBuilder
    var body: some View {
        ZStack {
            Color(.sRGB, red: 154 / 255, green: 211 / 255, blue: 110 / 255, opacity: 0.75)
                .edgesIgnoringSafeArea(.all)
            
            if let printerName = entry.configuration.printer?.name, let urlSafePrinter = printerName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {

                switch family {
                case .systemSmall:
                    
                    VStack(spacing: 10) {
                        JobDetailsView(printerName: printerName, entry: entry)
                    }.widgetURL(URL(string: "octopod://\(urlSafePrinter)")!)
                    
                default:
                    HStack() {
                        VStack(spacing: 10) {
                            JobDetailsView(printerName: printerName, entry: entry)
                        }
                        if let image = entry.cameraService?.image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                        } else {
                            Image("Image")
                                .resizable()
                        }
                    }
                    .padding(10.0)
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
struct OctoPodWidget14: Widget {
    let kind: String = "OctoPodWidget14"
    
    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: WidgetConfigurationIntent.self, provider: Provider()) { entry in
            OctoPodWidget14EntryView(entry: entry)
        }
        .configurationDisplayName("OctoPod")
        .description("Monitor and control your 3d printer via OctoPod")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@available(iOSApplicationExtension 13.0, *)
struct OctoPodWidget14_Previews: PreviewProvider {
    static var previews: some View {
        OctoPodWidget14EntryView(entry: SimpleEntry(date: Date(), configuration: WidgetConfigurationIntent(), printJobDataService: nil, cameraService: nil))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
