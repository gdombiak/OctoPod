import SwiftUI
import WidgetKit

struct JobDetailsView: View {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        // Show short version of date and hour
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    var printerName: String
    var entry: Provider.Entry
    
    var body: some View {
        VStack(spacing: 10) {
            Text(printerName)
                .font(.subheadline)
            
            if let progress = entry.printJobDataService?.progress, let eta = entry.printJobDataService?.printEstimatedCompletion, let printerStatus = entry.printJobDataService?.printerStatus {
                
                ProgressBarView(progress: .constant(progress))
                    .frame(width: 60.0, height: 60.0)
                // Display ETA only if progress is not 100%
                if printerStatus == "Printing" {
                    HStack(spacing: 30) {
                        Image("ETA")
                            .resizable()
                            .frame(width: 24.0, height: 24.0)
                        Text(eta)
                            .font(.footnote)
                            .minimumScaleFactor(0.65)
                    }.padding(.horizontal, 5)
                } else {
                    Text(printerStatus)
                        .font(.footnote)
                        .frame(width: nil, height: 24.0)
                }
            } else if let printerStatus = entry.printJobDataService?.printerStatus {
                Spacer()
                Text(printerStatus)
                    .font(.body)
                Spacer()
            }
            
            Text("\(entry.date, formatter: Self.dateFormatter)")
                .font(.caption2)
        }
    }
}

struct JobDetailsView_Previews: PreviewProvider {
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

    static var previews: some View {
        JobDetailsView(printerName: "MK3", entry: SimpleEntry(date: Date(), configuration: intent, printJobDataService: jobService, cameraService: nil))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}

