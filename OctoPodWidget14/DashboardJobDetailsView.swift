import WidgetKit
import SwiftUI

struct DashboardJobDetailsView: View {
    
    var entry: DashboardProvider.Entry
    var index: Int
    
    var body: some View {
        VStack() {
            if let printerJobs = entry.printJobDataServices {
                let printerJob = printerJobs[index]
                let printerName = printerJob.printerName
                let printerStatus = printerJob.printerStatus
                let eta = printerJob.printEstimatedCompletion
                
                Text(printerName)
                    .font(.subheadline)
                Spacer()
                
                if let progress = printerJob.progress {
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
                } else {
                    Text(printerStatus)
                        .font(.body)
                    Spacer()
                }
            }
        }
        .padding(2)
    }
}

struct DashboardJobDetailsView_Previews: PreviewProvider {
    static let configuration: DashboardWidgetConfigurationIntent = {
        let configuration = DashboardWidgetConfigurationIntent()
        configuration.theme = Theme.system
        return configuration
    }()

    //    static let jobService: PrintJobDataService = {
    //        let service = PrintJobDataService(name: "MK3", hostname: "", apiKey: "", username: nil, password: nil)
    //        service.printerStatus = "Printing"
    //        service.progress = 28.0
    //        service.printEstimatedCompletion = "9:30 PM"
    //        return service
    //    }()
    
    static let jobService: PrintJobDataService = {
        let service = PrintJobDataService(name: "MK3", hostname: "", apiKey: "", username: nil, password: nil)
        service.printerStatus = "Operational"
        return service
    }()
    
    static let jobServices = [jobService]
    
    static var previews: some View {
        DashboardJobDetailsView(entry: DashboardEntry(date: Date(), configuration: configuration, printJobDataServices: jobServices), index: 0)
            .previewContext(WidgetPreviewContext(family: .systemLarge))
    }
}
