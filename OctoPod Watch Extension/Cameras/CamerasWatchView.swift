import SwiftUI
import WatchKit

final class CamerasScreen: NSObject, ObservableObject, PrinterManagerDelegate {
    @Published var image: UIImage?
    @Published var errorText: String?
    @Published var showsError = false
    @Published var showsImage = false
    @Published var showsPrevious = false
    @Published var showsNext = false
    @Published var refreshEnabled = true

    private var index = 0
    private var cameraId = "0"
    private var load = WatchCameraPlayback()
    private lazy var streaming: MjpegStreaming = MjpegStreaming { _ in }

    func activate() {
        if !PrinterManager.instance.delegates.contains(where: { $0 === self }) {
            PrinterManager.instance.delegates.append(self)
        }
        render()
    }

    func deactivate() {
        streaming.stop()
        load.invalidate()
        PrinterManager.instance.remove(printerManagerDelegate: self)
    }

    func next() {
        index += 1
        image = nil
        render()
    }

    func previous() {
        index -= 1
        image = nil
        render()
    }

    func refresh() {
        render()
    }

    func printersChanged() {
    }

    func defaultPrinterChanged(newDefault: [String: Any]?) {
        index = 0
        DispatchQueue.main.async {
            self.render()
        }
    }

    func imageReceived(image: UIImage?, cameraId: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, WatchCameraPage.isSelected(cameraId, selectedCameraId: self.cameraId) else {
                return
            }
            if let image = image {
                self.image = image
                self.showsError = false
            } else {
                self.image = nil
                self.errorText = NSLocalizedString("Connection failed", comment: "")
                self.showsError = true
            }
            self.refreshEnabled = true
        }
    }

    private func render() {
        // Cancel the direct stream before the selected camera changes. A late finish returns
        // before stop() when its camera is no longer selected, so it must not be the only cancel.
        streaming.stop()
        load.invalidate()
        let loadToken = load.token
        guard let printer = PrinterManager.instance.defaultPrinter(), let cameras = PrinterManager.instance.cameras(printer: printer) else {
            showsPrevious = false
            showsNext = false
            showsImage = false
            showsError = false
            return
        }

        let controls = WatchCameraPage.controls(count: cameras.count, index: index)
        index = controls.index
        cameraId = controls.cameraId
        showsPrevious = controls.showsPrevious
        showsNext = controls.showsNext
        showsImage = controls.showsImage
        showsError = false

        guard !cameras.isEmpty else {
            return
        }

        let username = PrinterManager.instance.username(printer: printer)
        let password = PrinterManager.instance.password(printer: printer)
        let headers = PrinterManager.instance.headers(printer: printer)
        let preemptive = PrinterManager.instance.preemptive(printer: printer)
        let orientation = cameras[index].orientation
        let url = cameras[index].url
        let selectedId = cameraId
        refreshEnabled = false
        OctoPrintClient.instance.camera_take(url: url, username: username, password: password, headers: headers, preemptive: preemptive, orientation: orientation, cameraId: selectedId) { [weak self] requested, error in
            guard let self = self else {
                return
            }
            if requested {
                if let error = error {
                    self.showStreamError(error, cameraId: selectedId, loadToken: loadToken)
                }
            } else if WatchCameraPage.fallback(for: url) == .unsupportedHLS {
                self.showStreamError(NSLocalizedString("HLS not supported", comment: "Apple Watch cannot render HTTP Live Streaming feeds"), cameraId: selectedId, loadToken: loadToken)
            } else {
                DispatchQueue.main.async {
                    guard self.load.isCurrent(loadToken), WatchCameraPage.isSelected(selectedId, selectedCameraId: self.cameraId) else {
                        return
                    }
                    self.directFetch(url: url, orientation: orientation, username: username, password: password, cameraId: selectedId, loadToken: loadToken)
                }
            }
        }
    }

    private func directFetch(url: String, orientation: Int, username: String?, password: String?, cameraId: String, loadToken: Int) {
        guard load.isCurrent(loadToken), WatchCameraPage.isSelected(cameraId, selectedCameraId: self.cameraId) else {
            return
        }
        guard let streamURL = URL(string: url) else {
            showStreamError(NSLocalizedString("Connection failed", comment: ""), cameraId: cameraId, loadToken: loadToken)
            return
        }
        streaming.play(url: streamURL) { [weak self] playbackToken in
            guard let self = self else {
                return
            }
            if let username = username, let password = password {
                self.streaming.authenticationHandler = { _ in
                    (.useCredential, URLCredential(user: username, password: password, persistence: .forSession))
                }
            } else {
                self.streaming.authenticationHandler = nil
            }
            self.streaming.authenticationFailedHandler = { [weak self] in
                self?.showStreamError(NSLocalizedString("Authentication failed", comment: "HTTP authentication failed"), cameraId: cameraId, loadToken: loadToken)
            }
            self.streaming.didFinishWithErrors = { [weak self] error in
                self?.showStreamError(error.localizedDescription, cameraId: cameraId, loadToken: loadToken)
            }
            self.streaming.didFinishWithHTTPErrors = { [weak self] response in
                let message = String(format: NSLocalizedString("HTTP Request error", comment: "HTTP Request error info"), response.statusCode)
                self?.showStreamError(message, cameraId: cameraId, loadToken: loadToken)
            }
            self.streaming.imageHandler = { [weak self] image in
                guard let self = self, self.acceptsCameraCallback(cameraId: cameraId, loadToken: loadToken, playbackToken: playbackToken) else {
                    return
                }
                self.image = image
            }
            self.streaming.didFinishLoading = { [weak self] in
                guard let self = self, self.acceptsCameraCallback(cameraId: cameraId, loadToken: loadToken, playbackToken: playbackToken) else {
                    return
                }
                self.showsError = false
                self.refreshEnabled = true
                self.streaming.stopIfCurrent(token: playbackToken)
            }
            self.streaming.imageOrientation = UIImage.Orientation(rawValue: orientation) ?? .up
        }
    }

    private func acceptsCameraCallback(cameraId: String, loadToken: Int, playbackToken: Int) -> Bool {
        load.isCurrent(loadToken)
            && streaming.isCurrentPlayback(playbackToken)
            && WatchCameraPage.isSelected(cameraId, selectedCameraId: self.cameraId)
    }

    private func showStreamError(_ message: String, cameraId: String, loadToken: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.load.isCurrent(loadToken), WatchCameraPage.isSelected(cameraId, selectedCameraId: self.cameraId) else {
                return
            }
            self.image = nil
            self.errorText = message
            self.showsError = true
            self.refreshEnabled = true
        }
    }
}

struct CamerasWatchView: View {
    @StateObject private var screen = CamerasScreen()

    var body: some View {
        NavigationStack {
            VStack {
                VStack {
                    if screen.showsError, let error = screen.errorText {
                        Text(error)
                            .multilineTextAlignment(.center)
                    }
                    if screen.showsImage, let image = screen.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    }
                }
                .frame(maxHeight: .infinity)
                ZStack {
                    iconButton("Refresh", action: screen.refresh)
                        .disabled(!screen.refreshEnabled)
                    HStack {
                        if screen.showsPrevious {
                            iconButton("Prev", action: screen.previous)
                        }
                        Spacer()
                            .allowsHitTesting(false)
                        if screen.showsNext {
                            iconButton("Next", action: screen.next)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            .navigationTitle(NSLocalizedString("Cameras", comment: ""))
        }
        .onAppear(perform: screen.activate)
        .onDisappear(perform: screen.deactivate)
    }

    private func iconButton(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            WatchIcon(name: name, width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .frame(width: 40, height: 40)
        .fixedSize()
    }
}
