import SwiftUI
import CloudKit

struct PrintersRow: View {
    let tvPrinterManager: TVPrinterManager
    let page: Int
    let row: Int
    let geometry: GeometryProxy
    
    var body: some View {
        HStack {
            BriefView(printer: self.tvPrinterManager.printers[(page - 1) * 6 + (row * 2)])
                .frame(width: geometry.size.width / 2)
                .environmentObject(self.tvPrinterManager.connections[self.tvPrinterManager.printers[(page - 1) * 6 + (row * 2)]]!.websocket)
                .environmentObject(self.tvPrinterManager.connections[self.tvPrinterManager.printers[(page - 1) * 6 + (row * 2)]]!.cameraService)
            Divider()
            if self.tvPrinterManager.printers.count > (page - 1) * 6 + (row * 2) + 1 {
                BriefView(printer: self.tvPrinterManager.printers[(page - 1) * 6 + (row * 2) + 1])
                    .frame(width: geometry.size.width / 2)
                    .environmentObject(self.tvPrinterManager.connections[self.tvPrinterManager.printers[(page - 1) * 6 + (row * 2) + 1]]!.websocket)
                    .environmentObject(self.tvPrinterManager.connections[self.tvPrinterManager.printers[(page - 1) * 6 + (row * 2) + 1]]!.cameraService)
            }
        }
    }
}

struct ContentView: View {
    
    @ObservedObject private var tvPrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).tvPrinterManager }()
    
    var body: some View {
        GeometryReader { geometry in
            NavigationView {
                ScrollView(.vertical) {
                    if self.tvPrinterManager.iCloudConnected {
                        VStack {
                            if self.tvPrinterManager.printers.count > 0 {
                                PrintersRow(tvPrinterManager: self.tvPrinterManager, page: 1, row: 0, geometry: geometry)
                            }
                            if self.tvPrinterManager.printers.count > 2 {
                                Divider()
                                PrintersRow(tvPrinterManager: self.tvPrinterManager, page: 1, row: 1, geometry: geometry)
                            }
                            if self.tvPrinterManager.printers.count > 4 {
                                Divider()
                                PrintersRow(tvPrinterManager: self.tvPrinterManager, page: 1, row: 2, geometry: geometry)
                            }
                        }
                    } else {
                        Text("Connect to iCloud to retrieve list of printers from your iPad/iPhone")
                            .bold()
                            .foregroundColor(.red)
                    }
                }.navigationBarTitle("Printers")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
