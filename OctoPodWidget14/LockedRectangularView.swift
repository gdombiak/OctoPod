import SwiftUI
import WidgetKit

@available(iOS 13.0, *)
struct LockedRectangularView: View {

    var entry: Provider.Entry

    var body: some View {
        if let printJob = entry.printJobDataService, let progress = printJob.progress {
            VStack {
                HStack {
                    Text("\(printJob.printerStatus)")
                        .font(.callout)
                    Text(String(format: "%.0f%%", min(progress, 1.0)*100.0))
                        .font(.callout)
                }
                HStack(spacing: 5) {
                    Image("ETA")
                        .resizable()
                        .frame(width: 24.0, height: 24.0)
                    Text(printJob.printEstimatedCompletion)
                        .font(.callout)
                        .minimumScaleFactor(0.65)
                }.padding(.horizontal, 5)
            }
        } else {
            Image("OctoPod")
                .resizable()
                .scaledToFit()
        }
    }
}

@available(iOS 16.1, *)
struct LockedRectangularView_Previews: PreviewProvider {
    static var intent: WidgetConfigurationIntent = {
        let configuration = WidgetConfigurationIntent()
        configuration.printer = WidgetPrinter(identifier: "MK3", display: "MK3")
        configuration.printer?.name = "MK3"
        return configuration
    }()

    static var jobService: PrintJobDataService = {
        let jobService = PrintJobDataService(name: "MK3", hostname: "", apiKey: "", username: nil, password: nil, headers: nil, preemptive: false)
        jobService.printerStatus = "Printing"
        jobService.progress = 28.0
        jobService.printEstimatedCompletion = "9:30 PM"
        return jobService
    }()

    static var operationalJobService: PrintJobDataService = {
        let jobService = PrintJobDataService(name: "MK3", hostname: "", apiKey: "", username: nil, password: nil, headers: nil, preemptive: false)
        jobService.printerStatus = "Operational"
        jobService.progress = nil
        jobService.printEstimatedCompletion = ""
        return jobService
    }()

    static var previews: some View {
        Group {
            LockedRectangularView(entry: SimpleEntry(date: Date(), configuration: intent, printJobDataService: jobService, cameraService: nil))
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
            
            LockedRectangularView(entry: SimpleEntry(date: Date(), configuration: intent, printJobDataService: operationalJobService, cameraService: nil))
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
            
            LockedRectangularView(entry: SimpleEntry(date: Date(), configuration: intent, printJobDataService: nil, cameraService: nil))
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
        }
    }
}
