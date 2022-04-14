import WidgetKit
import SwiftUI
import Intents

struct DashboardProvider: IntentTimelineProvider {
    func placeholder(in context: Context) -> DashboardEntry {
        let configuration = DashboardWidgetConfigurationIntent()
        configuration.theme = Theme.system

        let jobService = PrintJobDataService(name: "MK3", hostname: "", apiKey: "", username: nil, password: nil, preemptive: false)
        jobService.printerStatus = "Printing"
        jobService.progress = 28.0
        jobService.printEstimatedCompletion = "9:30 PM"

        let jobService2 = PrintJobDataService(name: "Ender 3", hostname: "", apiKey: "", username: nil, password: nil, preemptive: false)
        jobService2.printerStatus = "Operational"

        let jobServices = [jobService, jobService2]
        
        return DashboardEntry(date: Date(), configuration: configuration, printJobDataServices: jobServices)
    }
    
    func getSnapshot(for configuration: DashboardWidgetConfigurationIntent, in context: Context, completion: @escaping (DashboardEntry) -> ()) {
        var printerJobs: Array<PrintJobDataService> = []
        if let printer = configuration.printer1 {
            if let name = printer.name, let hostname = printer.hostname, let apiKey = printer.apiKey {
                let service = PrintJobDataService(name: name, hostname: hostname, apiKey: apiKey, username: printer.username, password: printer.password, preemptive: printer.preemptiveAuth == 1)
                printerJobs.append(service)
            }
        }
        if let printer = configuration.printer2 {
            if let name = printer.name, let hostname = printer.hostname, let apiKey = printer.apiKey {
                let service = PrintJobDataService(name: name, hostname: hostname, apiKey: apiKey, username: printer.username, password: printer.password, preemptive: printer.preemptiveAuth == 1)
                printerJobs.append(service)
            }
        }
        if let printer = configuration.printer3 {
            if let name = printer.name, let hostname = printer.hostname, let apiKey = printer.apiKey {
                let service = PrintJobDataService(name: name, hostname: hostname, apiKey: apiKey, username: printer.username, password: printer.password, preemptive: printer.preemptiveAuth == 1)
                printerJobs.append(service)
            }
        }
        if let printer = configuration.printer4 {
            if let name = printer.name, let hostname = printer.hostname, let apiKey = printer.apiKey {
                let service = PrintJobDataService(name: name, hostname: hostname, apiKey: apiKey, username: printer.username, password: printer.password, preemptive: printer.preemptiveAuth == 1)
                printerJobs.append(service)
            }
        }
        
        if !printerJobs.isEmpty {
            let entry = DashboardEntry(date: Date(), configuration: configuration, printJobDataServices: printerJobs)
            
            // Fetch print job data in parallel to speed up things
            let group = DispatchGroup()
            for printJob in printerJobs {
                group.enter()
                printJob.updateData {
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                completion(entry)
            }
        } else {
            // Intent has not been configured so return empty print job data
            let entry = DashboardEntry(date: Date(), configuration: configuration, printJobDataServices: nil)
            completion(entry)
        }
    }
    
    func getTimeline(for configuration: DashboardWidgetConfigurationIntent, in context: Context, completion: @escaping (Timeline<DashboardEntry>) -> ()) {

        getSnapshot(for: configuration, in: context) { (entry: DashboardEntry) in
            let entries: [DashboardEntry] = [entry]
            
            // Check if any of the printers is printing
            var isPrinting: Bool = false
            if let printerJobs = entry.printJobDataServices {
                for printJob in printerJobs {
                    isPrinting = printJob.isPrinting()
                }
            }
            
            // Calcuate refresh date based on printing status
            let calendar = Calendar.current
            let refreshDate = isPrinting ? calendar.date(byAdding: .minute, value: 5, to: Date())! : calendar.date(byAdding: .hour, value: 1, to: Date())!

            let timeline = Timeline(entries: entries, policy: .after(refreshDate))
            completion(timeline)
        }
    }
}

struct DashboardEntry: TimelineEntry {
    let date: Date
    let configuration: DashboardWidgetConfigurationIntent
    let printJobDataServices: [PrintJobDataService]?
}

struct DashboardWidget14EntryView : View {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        // Show short version of date and hour
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    let widthPercentage = CGFloat(0.44)
    let heightPercentage = CGFloat(0.42)

    var entry: DashboardProvider.Entry
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.widgetFamily) var family
    
    @ViewBuilder
    var body: some View {
        GeometryReader { geometryProxy in
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
                
                if let printJobs = entry.printJobDataServices, !printJobs.isEmpty {
                    VStack() {
                        HStack() {
                            DashboardJobDetailsView(entry: entry, index: 0)
                                .frame(
                                    width: geometryProxy.size.width * widthPercentage,
                                    height: geometryProxy.size.height * heightPercentage)
                                .background(cellBackgroundColor())
                            Divider()
                            if printJobs.count >= 2 {
                                DashboardJobDetailsView(entry: entry, index: 1)
                                    .frame(
                                        width: geometryProxy.size.width * widthPercentage,
                                        height: geometryProxy.size.height * heightPercentage)
                                    .background(cellBackgroundColor())
                            } else {
                                Spacer()
                                    .frame(
                                        width: geometryProxy.size.width * widthPercentage,
                                        height: geometryProxy.size.height * heightPercentage)
                            }
                        }
                        Divider()
                        HStack(spacing: 10) {
                            if printJobs.count >= 3 {
                                    DashboardJobDetailsView(entry: entry, index: 2)
                                        .frame(
                                            width: geometryProxy.size.width * widthPercentage,
                                            height: geometryProxy.size.height * heightPercentage)
                                        .background(cellBackgroundColor())
                                    Divider()
                                    if printJobs.count >= 4 {
                                        DashboardJobDetailsView(entry: entry, index: 3)
                                            .frame(
                                                width: geometryProxy.size.width * widthPercentage,
                                                height: geometryProxy.size.height * heightPercentage)
                                            .background(cellBackgroundColor())
                                    } else {
                                        Spacer()
                                            .frame(
                                                width: geometryProxy.size.width * widthPercentage,
                                                height: geometryProxy.size.height * heightPercentage)
                                    }
                            } else {
                                Spacer()
                                    .frame(
                                        width: geometryProxy.size.width * widthPercentage,
                                        height: geometryProxy.size.height * heightPercentage)
                                Divider()
                                Spacer()
                                    .frame(
                                        width: geometryProxy.size.width * widthPercentage,
                                        height: geometryProxy.size.height * heightPercentage)
                            }
                        }
                        Text("\(entry.date, formatter: Self.dateFormatter)")
                            .font(.caption2)
                    }.padding(10)
                        .widgetURL(URL(string: "octopod://goToDashboard")!)
                } else {
                    // No printers have been selected so ask to configure widget
                    Text("Configure widget")
                }            
            }
        }
    }
    
    func cellBackgroundColor() -> Color {
        switch self.entry.configuration.theme {
        case Theme.light:
            return Color(.sRGB, red: 204 / 255, green: 204 / 255, blue: 204 / 255, opacity: 1)
        case Theme.dark:
            return Color(.sRGB, red: 115 / 255, green: 115 / 255, blue: 115 / 255, opacity: 1)
        case Theme.system:
            if colorScheme == .dark {
                return Color(.sRGB, red: 115 / 255, green: 115 / 255, blue: 115 / 255, opacity: 1)
            } else {
                return Color(.sRGB, red: 204 / 255, green: 204 / 255, blue: 204 / 255, opacity: 1)
            }
        default:
            return Color(.sRGB, red: 154 / 255, green: 192 / 255, blue: 110 / 255, opacity: 1)
        }
    }
}

struct DashboardWidget14EntryView_Previews: PreviewProvider {
    static let configuration: DashboardWidgetConfigurationIntent = {
        let configuration = DashboardWidgetConfigurationIntent()
        configuration.theme = Theme.system
        return configuration
    }()

    static let jobService1: PrintJobDataService = {
        let service = PrintJobDataService(name: "MK3", hostname: "", apiKey: "", username: nil, password: nil, preemptive: false)
        service.printerStatus = "Printing"
        service.progress = 28.0
        service.printEstimatedCompletion = "9:30 PM"
        return service
    }()
    
    static let jobService2: PrintJobDataService = {
        let service = PrintJobDataService(name: "MK3", hostname: "", apiKey: "", username: nil, password: nil, preemptive: false)
        service.printerStatus = "Paused"
        service.progress = 28.0
        service.printEstimatedCompletion = "9:30 PM"
        return service
    }()
    
    static let jobService3: PrintJobDataService = {
        let service = PrintJobDataService(name: "MK3", hostname: "", apiKey: "", username: nil, password: nil, preemptive: false)
        service.printerStatus = "Operational"
        return service
    }()
    
    static let jobServices = [jobService1, jobService2, jobService3]
    
    static var previews: some View {
        DashboardWidget14EntryView(entry: DashboardEntry(date: Date(), configuration: configuration, printJobDataServices: jobServices))
            .previewContext(WidgetPreviewContext(family: .systemLarge))
    }
}


struct DashboardWidget: Widget {
    let kind: String = "OctoPodDashboardWidget"
    
    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: DashboardWidgetConfigurationIntent.self, provider: DashboardProvider()) { entry in
            DashboardWidget14EntryView(entry: entry)
        }
        .configurationDisplayName(NSLocalizedString("Dashboard", comment: ""))
        .description(NSLocalizedString("Dashboard for multiple printers", comment: ""))
        .supportedFamilies([.systemLarge])
    }
}

