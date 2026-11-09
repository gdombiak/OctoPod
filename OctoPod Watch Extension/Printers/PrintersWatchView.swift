import SwiftUI
import WatchKit

final class PrintersScreen: NSObject, ObservableObject, PrinterManagerDelegate {
    @Published private(set) var list = WatchPrinterList.state(for: [])
    @Published var refreshEnabled = true

    private var printers: [[String: Any]] = []

    func activate() {
        if !PrinterManager.instance.delegates.contains(where: { $0 === self }) {
            PrinterManager.instance.delegates.append(self)
        }
        reload()
    }

    func deactivate() {
        PrinterManager.instance.remove(printerManagerDelegate: self)
    }

    func select(index: Int) {
        guard printers.indices.contains(index) else {
            return
        }
        let printerName = PrinterManager.instance.name(printer: printers[index])
        PrinterManager.instance.changeDefaultPrinter(printerName: printerName)
        reload()
        OctoPrintClient.instance.configure()
    }

    func refresh() {
        refreshEnabled = false
        WatchSessionManager.instance.refreshPrinters {
            DispatchQueue.main.async {
                self.refreshEnabled = true
            }
        }
    }

    func printersChanged() {
        DispatchQueue.main.async {
            self.reload()
        }
    }

    func defaultPrinterChanged(newDefault: [String: Any]?) {
    }

    func imageReceived(image: UIImage?, cameraId: String) {
    }

    private func reload() {
        printers = WatchPrinterList.sorted(PrinterManager.instance.printers)
        list = WatchPrinterList.state(for: printers)
    }
}

struct PrintersWatchView: View {
    @StateObject private var screen = PrintersScreen()

    var body: some View {
        NavigationStack {
            VStack {
                if screen.list.showsSyncPrompt {
                    Text(NSLocalizedString("Open the iPhone app, it will share printer data with the watch", comment: ""))
                        .multilineTextAlignment(.center)
                }
                if screen.list.showsRefresh {
                    List {
                        ForEach(Array(screen.list.rows.enumerated()), id: \.offset) { index, row in
                            Button {
                                screen.select(index: index)
                            } label: {
                                HStack {
                                    Text(row.name)
                                    Spacer()
                                    if row.isDefault {
                                        WatchIcon(name: "Checkmark", width: 12, height: 9)
                                    }
                                }
                            }
                        }
                        WatchRefreshButton(enabled: screen.refreshEnabled, action: screen.refresh)
                            .padding(.bottom, 8)
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("Printers", comment: ""))
        }
        .onAppear(perform: screen.activate)
        .onDisappear(perform: screen.deactivate)
    }
}
