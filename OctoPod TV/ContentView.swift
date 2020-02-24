import SwiftUI
import CloudKit

struct ContentView: View {

    @ObservedObject private var tvPrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).tvPrinterManager }()
    @ObservedObject private var service = ViewService()
    @ObservedObject private var cameraService = CameraService()
    @State private var selectedPrinter: Printer?
        
    var body: some View {
        NavigationView {
            VStack {
                MonitorPrinter()
                Divider()
                if tvPrinterManager.iCloudConnected {
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(tvPrinterManager.printers, id: \.name) { printer in
                                Button(action: {
                                    self.selectedPrinter = printer
                                    // Open websocket to the new selected printer
                                    self.service.clearValues()
                                    self.service.connectToServer(printer: printer)
                                    self.cameraService.connectToServer(printer: printer)
                                }) {
                                    HStack {
                                        Image("Printer")
                                        Text(printer.name)
                                    }
                                }
                            }
                        }
                    }.frame(height: 100.0).alignmentGuide(HorizontalAlignment.center) { (d) -> CGFloat in
                        d[.leading] + d.width / 2.0 - (d[explicit: .top] ?? 0)
                    }
                } else {
                    Text("Connect to iCloud to retrieve list of printers from your iPad/iPhone")
                        .bold()
                        .foregroundColor(.red)
                }

            }.navigationBarTitle(self.selectedPrinter?.name ?? "")
        }
        .environmentObject(service)
        .environmentObject(cameraService)
        .onAppear() {
            if let printer = self.tvPrinterManager.defaultPrinter {
                self.selectedPrinter = printer
            } else {
                let printers = self.tvPrinterManager.printers
                if !printers.isEmpty {
                    self.selectedPrinter = printers[0]
                }
            }
            if let printer = self.selectedPrinter {
                // Open websocket to the new selected printer
                self.service.connectToServer(printer: printer)
                // Start rendering camera of new selected printer
                self.cameraService.connectToServer(printer: printer)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
