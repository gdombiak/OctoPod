import WidgetKit
import SwiftUI
import Intents

struct LargetDetailsView: View {
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
        if let cameraService = entry.cameraService {
            VStack() {
                HStack() {
                    Text(printerName)
                        .font(.caption)
                    Spacer()
                    if let progress = entry.printJobDataService?.progress, let eta = entry.printJobDataService?.printEstimatedCompletion, let printerStatus = entry.printJobDataService?.printerStatus {
                        
                        Text(String(format: "%.0f %%", min(progress, 1.0)*100.0))
                            .font(.caption)
                        
                        Spacer()
                        
                        // Display ETA only if progress is not 100%
                        if printerStatus == "Printing" {
                            Text(eta)
                                .font(.caption)
                                .minimumScaleFactor(0.65)
                        } else {
                            Text(printerStatus)
                                .font(.caption)
                        }
                    } else if let printerStatus = entry.printJobDataService?.printerStatus {
                        Text(printerStatus)
                            .font(.caption)
                    }
                }
                
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
                Spacer()
                Text("\(entry.date, formatter: Self.dateFormatter)")
                    .font(.caption2)
            }.padding(5)
        } else {
            // No camera was configured in the widget
            Text("Configure widget")
        }
    }
}

struct LargetDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        LargetDetailsView(printerName: "MK3", entry: SimpleEntry(date: Date(), configuration: WidgetConfigurationIntent(), printJobDataService: nil, cameraService: nil))
    }
}
