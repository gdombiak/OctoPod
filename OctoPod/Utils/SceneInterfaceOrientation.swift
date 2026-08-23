import UIKit

/// Interface orientation of the window scene that owns the relevant UI.
/// Replaces `UIApplication.shared.statusBarOrientation` / `keyWindow` without
/// a global window lookup when local ownership exists.
enum SceneInterfaceOrientation {
    /// Prefers `window.windowScene.interfaceOrientation`.
    /// If the window is not attached to a scene, infers portrait/landscape from bounds.
    /// If no window is provided, uses the foreground active scene.
    static func current(from window: UIWindow?) -> UIInterfaceOrientation {
        if let orientation = window?.windowScene?.interfaceOrientation, orientation != .unknown {
            return orientation
        }
        if let window {
            return window.bounds.height >= window.bounds.width ? .portrait : .landscapeRight
        }
        if let orientation = foregroundWindowScene()?.interfaceOrientation, orientation != .unknown {
            return orientation
        }
        return .portrait
    }

    static func isPortrait(from window: UIWindow?) -> Bool {
        current(from: window).isPortrait
    }

    /// Scene that owns `view`, otherwise the foreground active scene.
    static func windowScene(for view: UIView?) -> UIWindowScene? {
        if let scene = view?.window?.windowScene {
            return scene
        }
        return foregroundWindowScene()
    }

    static func foregroundWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
    }

    /// Presenter that used to be `UIApplication.shared.keyWindow?.rootViewController`.
    static func presenter(for viewController: UIViewController) -> UIViewController {
        viewController.view.window?.rootViewController ?? viewController
    }
}
