import SwiftUI
import WatchKit

@main
struct OctoPodWatchApp: App {
    @WKApplicationDelegateAdaptor(ExtensionDelegate.self) private var extensionDelegate

    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
    }
}

struct WatchRootView: View {
    @State private var page = WatchPage.initial(printerCount: PrinterManager.instance.printers.count)

    var body: some View {
        TabView(selection: $page) {
            PrintersWatchView()
                .tag(WatchPage.printers)
            PanelWatchView(isSelected: page == .panel)
                .tag(WatchPage.panel)
            CamerasWatchView()
                .tag(WatchPage.cameras)
        }
        .tabViewStyle(.page)
    }
}

enum WatchImages {
    static func named(_ name: String) -> UIImage {
        if let image = UIImage(named: name, in: watchAppBundle, with: nil) {
            return image
        }
        return UIImage(named: name) ?? UIImage()
    }

    /// Storyboard images live in the watch app catalog. The extension is nested at Watch.app/PlugIns/Extension.appex.
    private static let watchAppBundle: Bundle = {
        let appURL = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
        return Bundle(url: appURL) ?? .main
    }()
}

struct WatchIcon: View {
    var name: String
    var width: CGFloat
    var height: CGFloat

    var body: some View {
        Image(uiImage: WatchImages.named(name))
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(width: width, height: height)
    }
}

struct WatchRefreshButton: View {
    var enabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            WatchIcon(name: "Refresh", width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: 40, height: 40)
        .fixedSize()
        .disabled(!enabled)
        .frame(maxWidth: .infinity, maxHeight: 40)
    }
}
