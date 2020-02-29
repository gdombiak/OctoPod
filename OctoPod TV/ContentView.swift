import SwiftUI
import CloudKit

private let printersPerPage = 4
private let printersPerRow = 2

struct PrintersRow: View {
    let tvPrinterManager: TVPrinterManager
    let page: Int
    let row: Int
    let geometry: GeometryProxy
    
    var body: some View {
        HStack {
            BriefView(printer: self.tvPrinterManager.printers[(page - 1) * printersPerPage + (row * printersPerRow)])
                .frame(width: geometry.size.width / 2)
                .environmentObject(self.tvPrinterManager.connections[self.tvPrinterManager.printers[(page - 1) * printersPerPage + (row * printersPerRow)]]!.websocket)
                .environmentObject(self.tvPrinterManager.connections[self.tvPrinterManager.printers[(page - 1) * printersPerPage + (row * printersPerRow)]]!.cameraService)
            Divider()
            if self.tvPrinterManager.printers.count > (page - 1) * printersPerPage + (row * printersPerRow) + 1 {
                BriefView(printer: self.tvPrinterManager.printers[(page - 1) * printersPerPage + (row * 2) + 1])
                    .frame(width: geometry.size.width / 2)
                    .environmentObject(self.tvPrinterManager.connections[self.tvPrinterManager.printers[(page - 1) * printersPerPage + (row * printersPerRow) + 1]]!.websocket)
                    .environmentObject(self.tvPrinterManager.connections[self.tvPrinterManager.printers[(page - 1) * printersPerPage + (row * printersPerRow) + 1]]!.cameraService)
            }
        }
    }
}

struct PaginationButtons: View {
    let tvPrinterManager: TVPrinterManager
    @Binding var page: Int
    let pages: Int
    
    var body: some View {
        HStack {
            Spacer()
            Button(action: {
                // Disconnect printers from old page
                for index in 1...printersPerPage {
                    self.tvPrinterManager.disconnectFromServer(printerIndex: (self.page - 1) * printersPerPage + index - 1)
                }
                self.page = self.page - 1
                // Connect printers of new page
                for index in 1...printersPerPage {
                    self.tvPrinterManager.connectToServer(printerIndex: (self.page - 1) * printersPerPage + index - 1)
                }
            }) {
                HStack {
                    Image("Back")
                    Text("Back")
                }
            }.disabled(self.page == 1)
            Spacer()
            Text("\(page) / \(pages)")
            Spacer()
            Button(action: {
                // Disconnect printers from old page
                for index in 1...printersPerPage {
                    self.tvPrinterManager.disconnectFromServer(printerIndex: (self.page - 1) * printersPerPage + index - 1)
                }
                self.page = self.page + 1
                // Connect printers of new page
                for index in 1...printersPerPage {
                    self.tvPrinterManager.connectToServer(printerIndex: (self.page - 1) * printersPerPage + index - 1)
                }
            }) {
                HStack {
                    Text("Next")
                    Image("Next")
                }
            }.disabled(self.page >= self.pages)
            Spacer()
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
                        if self.tvPrinterManager.printers.count > (self.page - 1) * printersPerPage {
                            VStack {
                                PrintersRow(tvPrinterManager: self.tvPrinterManager, page: self.page, row: 0, geometry: geometry)
                                if self.tvPrinterManager.printers.count > (self.page - 1) * printersPerPage + printersPerRow {
                                    Divider()
                                    PrintersRow(tvPrinterManager: self.tvPrinterManager, page: self.page, row: 1, geometry: geometry)
                                }
                                if self.pages > 1 {
                                    Spacer()
                                    PaginationButtons(tvPrinterManager: self.tvPrinterManager, page: self.$page, pages: self.pages)
                                }
                            }
                        } else {
                            Spacer()
                            Text("Retrieving printers information")
                                .bold()
                            Spacer()
                        }
                    } else {
                        Spacer()
                        Text("Connect to iCloud to retrieve list of printers from your iPad/iPhone")
                            .bold()
                            .foregroundColor(.red)
                        Spacer()
                    }
                }.navigationBarTitle("Printers")
            }.onReceive(self.tvPrinterManager.$printers) { printers in
                // Close existing socket connections and open new ones for printers in page 1
                if self.page > 1 {
                    // Disconnect printers from old page
                    for index in 1...printersPerPage {
                        self.tvPrinterManager.disconnectFromServer(printerIndex: (self.page - 1) * printersPerPage + index - 1)
                    }
                    // Update current page
                    self.page = 1
                }
                // Connect printers of first page
                for index in 1...printersPerPage {
                    self.tvPrinterManager.connectToServer(printerIndex: index - 1)
                }
                
                // Update total number of pages
                self.pages = Int(ceil(Float(printers.count) / Float(printersPerPage)))
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
