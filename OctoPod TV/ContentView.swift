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
    @State private var selectedPrinter: Printer?

    var body: some View {
        NavigationView {
            VStack {
                MonitorPrinter()
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(printerManager.getPrinters(), id: \.self) {printer in
                            Button(action: {
                                self.selectedPrinter = printer
                                // Open websocket to the new selected printer
                                self.service.clearValues()
                                self.service.connectToServer(printer: printer)
                            }) {
                                Text(printer.name)
                            }
                        }
                    }
                }
            }.navigationBarTitle(self.selectedPrinter?.name ?? "")
        }
        .environmentObject(service)
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
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
