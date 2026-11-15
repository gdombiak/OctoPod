import SwiftUI

struct PrintersRow: View {
    let tvPrinterManager: TVPrinterManager
    let printers: [Printer]
    let geometry: GeometryProxy

    var body: some View {
        HStack {
            ForEach(printers, id: \.objectID) { printer in
                if let connection = tvPrinterManager.connections[printer.objectID] {
                    BriefView(printer: printer)
                        .frame(width: geometry.size.width / 2)
                        .environmentObject(connection.websocket)
                        .environmentObject(connection.cameraService)
                }
                if printer.objectID == printers.first?.objectID {
                    Divider()
                }
            }
            if printers.count == 1 {
                Spacer().frame(width: geometry.size.width / 2)
            }
        }
    }
}

struct PaginationButtons: View {
    @ObservedObject var tvPrinterManager: TVPrinterManager

    var body: some View {
        HStack {
            Spacer()
            Button {
                tvPrinterManager.showPage(tvPrinterManager.page - 1)
            } label: {
                HStack {
                    Image("Back")
                    Text("Back")
                }
            }
            .disabled(tvPrinterManager.page == 1)
            Spacer()
            Text("\(tvPrinterManager.page) / \(tvPrinterManager.pages)")
            Spacer()
            Button {
                tvPrinterManager.showPage(tvPrinterManager.page + 1)
            } label: {
                HStack {
                    Text("Next")
                    Image("Next")
                }
            }
            .disabled(tvPrinterManager.page >= tvPrinterManager.pages)
            Spacer()
        }
    }
}

struct ContentView: View {
    
    @ObservedObject private var tvPrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).tvPrinterManager }()
    
    var body: some View {
        GeometryReader { geometry in
            let printers = tvPrinterManager.visiblePrinters
            NavigationView {
                Group {
                    if self.tvPrinterManager.iCloudConnected {
                        if !printers.isEmpty {
                            VStack {
                                PrintersRow(tvPrinterManager: self.tvPrinterManager, printers: Array(printers.prefix(2)), geometry: geometry)
                                if printers.count > 2 {
                                    Divider()
                                    PrintersRow(tvPrinterManager: self.tvPrinterManager, printers: Array(printers.dropFirst(2)), geometry: geometry)
                                }
                                if self.tvPrinterManager.pages > 1 {
                                    Spacer()
                                    PaginationButtons(tvPrinterManager: self.tvPrinterManager)
                                } else {
                                    Spacer()
                                }
                            }
                        } else {
                            Text("Retrieving printers information")
                                .bold()
                        }
                    } else {
                        Text("Connect to iCloud to retrieve list of printers from your iPad/iPhone")
                            .bold()
                            .foregroundColor(.red)
                    }
                }.navigationTitle(Text("Printers"))
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
