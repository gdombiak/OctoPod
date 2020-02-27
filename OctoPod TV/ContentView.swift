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

struct PaginationButtons: View {
    @Binding var page: Int
    let pages: Int
    
    var body: some View {
        HStack {
            if self.page > 1 {
                Button(action: {
                    self.page = self.page - 1
                    NSLog("Going Back")
                }) {
                    Text("Go Back")
                }
            } else {
                EmptyView()
            }
            Spacer()
            if self.page < self.pages {
                Button(action: {
                    self.page = self.page + 1
                    NSLog("Going Next")
                }) {
                    Text("Go Next")
                }
            } else {
                EmptyView()
            }
        }
    }
}

struct ContentView: View {
    
    @ObservedObject private var tvPrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).tvPrinterManager }()
    @State private var page: Int = 1
    @State private var pages: Int = 1
    
    var body: some View {
        GeometryReader { geometry in
            NavigationView {
                ScrollView(.vertical) {
                    if self.tvPrinterManager.iCloudConnected {
                        VStack {
                            if self.tvPrinterManager.printers.count > (self.page - 1) * 6 {
                                PrintersRow(tvPrinterManager: self.tvPrinterManager, page: self.page, row: 0, geometry: geometry)
                            }
                            if self.tvPrinterManager.printers.count > (self.page - 1) * 6 + 2 {
                                Divider()
                                PrintersRow(tvPrinterManager: self.tvPrinterManager, page: self.page, row: 1, geometry: geometry)
                            }
                            if self.tvPrinterManager.printers.count > (self.page - 1) * 6 + 4 {
                                Divider()
                                PrintersRow(tvPrinterManager: self.tvPrinterManager, page: self.page, row: 2, geometry: geometry)
                            }
                            if self.pages > 1 {
                                PaginationButtons(page: self.$page, pages: self.pages)
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
