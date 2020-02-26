import SwiftUI
import CloudKit

struct ContentView: View {
    
    @ObservedObject private var tvPrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).tvPrinterManager }()
    
    var body: some View {
        GeometryReader { geometry in
            NavigationView {
                if self.tvPrinterManager.iCloudConnected {
                    ScrollView(.vertical) {
                        VStack {
                            ForEach(self.tvPrinterManager.printers, id: \.name) { printer in
                                Group {
                                    HStack {
                                        BriefView(printer: printer)
                                            .frame(width: geometry.size.width / 2)
                                            .environmentObject(self.tvPrinterManager.connections[printer]!.websocket)
                                            .environmentObject(self.tvPrinterManager.connections[printer]!.cameraService)
                                        Divider()
                                    }
                                    Divider()
                                }
                            }
                        }
                    }.navigationBarTitle("Printers")
                } else {
                    Text("Connect to iCloud to retrieve list of printers from your iPad/iPhone")
                        .bold()
                        .foregroundColor(.red)
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
