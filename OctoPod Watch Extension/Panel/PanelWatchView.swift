import SwiftUI
import WatchKit

final class PanelScreen: NSObject, ObservableObject, PrinterManagerDelegate, PanelManagerDelegate {
    @Published private(set) var panel = WatchPanelState()
    @Published private(set) var title = NSLocalizedString("Panel", comment: "")
    @Published var refreshEnabled = true
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    @Published var showAlert = false
    @Published var confirmPause = false
    @Published var confirmCancel = false

    private var printerURL: String?
    private var lifecycle = WatchPanelLifecycle()

    func handleAppear() {
        if lifecycle.appear() {
            activate()
        }
    }

    func handleScene(_ phase: WatchScenePhase, panelSelected: Bool) {
        if lifecycle.sceneChanged(to: phase, panelSelected: panelSelected) {
            activate()
        }
    }

    func activate() {
        if !PrinterManager.instance.delegates.contains(where: { $0 === self }) {
            PrinterManager.instance.delegates.append(self)
        }
        if !PanelManager.instance.delegates.contains(where: { $0 === self }) {
            PanelManager.instance.delegates.append(self)
        }
        OctoPrintClient.instance.configure()

        if let printer = PrinterManager.instance.defaultPrinter() {
            let currentPrinterName = PrinterManager.instance.name(printer: printer)
            title = currentPrinterName
            let url = PrinterManager.instance.hostname(printer: printer)
            if printerURL != url {
                panel.clearFields()
            }
            printerURL = url
            if let printerName = PanelManager.instance.printerName, let panelInfo = PanelManager.instance.panelInfo, currentPrinterName == printerName {
                apply(panelInfo)
                render(forceRefresh: false)
            } else {
                render(forceRefresh: true)
            }
        } else {
            panel.clearFields()
            printerURL = nil
        }
    }

    func deactivate() {
        PrinterManager.instance.remove(printerManagerDelegate: self)
        PanelManager.instance.remove(panelManagerDelegate: self)
    }

    func refresh() {
        render(forceRefresh: true)
    }

    func resumeJob() {
        OctoPrintClient.instance.resumeCurrentJob { requested, error in
            self.finish(requested: requested, error: error, failureKey: "Notify failed resume job", log: "resume")
        }
    }

    func pauseConfirmed() {
        OctoPrintClient.instance.pauseCurrentJob { requested, error in
            self.finish(requested: requested, error: error, failureKey: "Notify failed pause job", log: "pause")
        }
    }

    func cancelConfirmed() {
        OctoPrintClient.instance.cancelCurrentJob { requested, error in
            self.finish(requested: requested, error: error, failureKey: "Notify failed cancel job", log: "cancel")
        }
    }

    func printersChanged() {
    }

    func defaultPrinterChanged(newDefault: [String: Any]?) {
        DispatchQueue.main.async {
            if let printer = newDefault {
                self.title = PrinterManager.instance.name(printer: printer)
                self.printerURL = PrinterManager.instance.hostname(printer: printer)
            } else {
                self.printerURL = nil
            }
            self.panel.clearFields()
        }
    }

    func imageReceived(image: UIImage?, cameraId: String) {
    }

    func panelInfoUpdate(printerName: String, panelInfo: [String: Any]) {
        DispatchQueue.main.async {
            self.apply(panelInfo)
        }
    }

    func updateComplications(printerName: String, printerState: String, completion: Double, palette2LastPing: String?, palette2LastVariation: String?, palette2MaxVariation: String?) {
    }

    private func apply(_ panelInfo: [String: Any]) {
        let width = Double(WKInterfaceDevice.current().screenBounds.size.width)
        panel.apply(panelInfo: panelInfo, screenWidth: width)
    }

    private func render(forceRefresh: Bool) {
        refreshEnabled = false
        PanelManager.instance.refresh(forceRefresh: forceRefresh) { _ in
            DispatchQueue.main.async {
                self.refreshEnabled = true
            }
        }
    }

    private func finish(requested: Bool, error: String?, failureKey: String, log: String) {
        if !requested {
            if let error = error {
                NSLog("Failed to request to \(log) job. Error: \(error)")
            }
            DispatchQueue.main.async {
                self.alertTitle = NSLocalizedString("Job", comment: "")
                self.alertMessage = NSLocalizedString(failureKey, comment: "")
                self.showAlert = true
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.render(forceRefresh: true)
            }
        }
    }
}

struct PanelWatchView: View {
    var isSelected: Bool
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var screen = PanelScreen()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if screen.panel.showsError, let error = screen.panel.errorText {
                        Text(error)
                            .font(.caption2)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                    if let state = screen.panel.stateText {
                        Text(state)
                            .foregroundStyle(Color(red: 0.08, green: 0.65, blue: 0.03))
                            .frame(maxWidth: .infinity)
                    }
                    labeledRow(icon: "Progress", text: screen.panel.completionText)
                    labeledRow(icon: "ETA", text: screen.panel.timeLeftText)
                    labeledRow(icon: "Completion", text: screen.panel.etaText)
                    HStack {
                        WatchIcon(name: "Extruder", width: 14, height: 24)
                        Text(screen.panel.tool0Text).font(.caption2)
                        Spacer()
                        WatchIcon(name: "Bed", width: 24, height: 24)
                        Text(screen.panel.bedTempText ?? "").font(.caption2)
                    }
                    toolRow(screen.panel.row1, leadingIcon: "Extruder", trailingIcon: "Chamber", trailingWidth: 24)
                    toolRow(screen.panel.row2, leadingIcon: "Extruder", trailingIcon: "Extruder", trailingWidth: 14)
                    if screen.panel.row3.visible {
                        HStack {
                            slot(icon: "Extruder", width: 14, slot: screen.panel.row3.leading)
                            Spacer()
                        }
                    }
                    if screen.panel.showsPalette2 {
                        HStack {
                            WatchIcon(name: "Palette2", width: 15, height: 24)
                            Text(screen.panel.palette2LastPing ?? "").font(.caption2)
                            Spacer()
                            Text(screen.panel.palette2LastVariance ?? "").font(.caption2)
                        }
                    }
                    if screen.panel.jobButtons.showsGroup {
                        Divider()
                        HStack {
                            if screen.panel.jobButtons.showsPause {
                                jobButton("Pause", action: { screen.confirmPause = true })
                            }
                            if screen.panel.jobButtons.showsResume {
                                jobButton("Resume", action: screen.resumeJob)
                            }
                            Spacer()
                            if screen.panel.jobButtons.showsCancel {
                                jobButton("Cancel", action: { screen.confirmCancel = true })
                            }
                        }
                    }
                    Divider()
                    WatchRefreshButton(enabled: screen.refreshEnabled, action: screen.refresh)
                        .padding(.bottom, 18)
                }
            }
            .navigationTitle(screen.title)
        }
        .onAppear(perform: screen.handleAppear)
        .onDisappear(perform: screen.deactivate)
        .onChange(of: scenePhase) { newPhase in
            screen.handleScene(Self.watchPhase(newPhase), panelSelected: isSelected)
        }
        .alert(screen.alertTitle, isPresented: $screen.showAlert) {
            Button(NSLocalizedString("Dismiss", comment: "")) {}
        } message: {
            Text(screen.alertMessage)
        }
        .confirmationDialog(NSLocalizedString("Confirm", comment: ""), isPresented: $screen.confirmPause, titleVisibility: .visible) {
            Button(NSLocalizedString("Yes", comment: ""), action: screen.pauseConfirmed)
            Button(NSLocalizedString("No", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("Do you want to pause the job?", comment: ""))
        }
        .confirmationDialog(NSLocalizedString("Confirm", comment: ""), isPresented: $screen.confirmCancel, titleVisibility: .visible) {
            Button(NSLocalizedString("Yes", comment: ""), action: screen.cancelConfirmed)
            Button(NSLocalizedString("No", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("Do you want to cancel job?", comment: ""))
        }
    }

    private static func watchPhase(_ phase: ScenePhase) -> WatchScenePhase {
        switch phase {
        case .active:
            return .active
        case .background:
            return .background
        case .inactive:
            return .inactive
        @unknown default:
            return .inactive
        }
    }

    private func labeledRow(icon: String, text: String?) -> some View {
        HStack {
            WatchIcon(name: icon, width: 24, height: 24)
            Spacer()
            Text(text ?? "").font(.caption2)
        }
    }

    @ViewBuilder
    private func toolRow(_ row: WatchToolRow, leadingIcon: String, trailingIcon: String, trailingWidth: CGFloat) -> some View {
        if row.visible {
            HStack {
                slot(icon: leadingIcon, width: 14, slot: row.leading)
                Spacer()
                slot(icon: trailingIcon, width: trailingWidth, slot: row.trailing)
            }
        }
    }

    private func slot(icon: String, width: CGFloat, slot: WatchTempSlot) -> some View {
        HStack(spacing: 2) {
            WatchIcon(name: icon, width: width, height: 24)
            Text(slot.text).font(.caption2)
        }
        .opacity(slot.enabled ? 1 : 0.6)
    }

    private func jobButton(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            WatchIcon(name: name, width: 40, height: 40)
        }
        .buttonStyle(.plain)
    }
}
