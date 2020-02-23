//
//  ContentView.swift
//  OctoPod TV
//
//  Created by Gaston Dombiak on 2/21/20.
//  Copyright © 2020 Gaston Dombiak. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    let printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()

    @ObservedObject private var service = ViewService()
    @ObservedObject private var cameraService = CameraService()
    @State private var selectedPrinter: Printer?

    var body: some View {
        NavigationView {
            VStack {
                MonitorPrinter()
                Divider()
                Text("Printers")
                    .font(.headline)
                ScrollView() {
                    HStack {
                        ForEach(printerManager.getPrinters(), id: \.self) {printer in
                            Button(action: {
                                self.selectedPrinter = printer
                                // Open websocket to the new selected printer
                                self.service.clearValues()
                                self.service.connectToServer(printer: printer)
                                self.cameraService.connectToServer(printer: printer)
                            }) {
                                Text(printer.name)
                            }
                        }
                    }
                }.alignmentGuide(HorizontalAlignment.center) { (d) -> CGFloat in
                    d[.leading] + d.width / 2.0 - (d[explicit: .top] ?? 0)
                }
            }.navigationBarTitle(self.selectedPrinter?.name ?? "")
        }
        .environmentObject(service)
        .environmentObject(cameraService)
        .onAppear() {
            if let printer = self.printerManager.getDefaultPrinter() {
                self.selectedPrinter = printer
            } else {
                let printers = self.printerManager.getPrinters()
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
