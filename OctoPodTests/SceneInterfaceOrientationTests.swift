import XCTest
@testable import OctoPod

final class SceneInterfaceOrientationTests: XCTestCase {

    func testPortraitWindowBoundsAreTreatedAsPortraitWhenSceneIsUnavailable() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        try XCTSkipIf(window.windowScene != nil, "Host attached a scene; bounds fallback is not exercised")
        XCTAssertEqual(SceneInterfaceOrientation.current(from: window), .portrait)
        XCTAssertTrue(SceneInterfaceOrientation.isPortrait(from: window))
    }

    func testLandscapeWindowBoundsAreTreatedAsLandscapeRightWhenSceneIsUnavailable() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 844, height: 390))
        try XCTSkipIf(window.windowScene != nil, "Host attached a scene; bounds fallback is not exercised")
        XCTAssertEqual(SceneInterfaceOrientation.current(from: window), .landscapeRight)
        XCTAssertFalse(SceneInterfaceOrientation.isPortrait(from: window))
    }

    func testPresenterFallsBackToTheViewControllerWhenItHasNoWindow() {
        let controller = UIViewController()
        XCTAssertTrue(SceneInterfaceOrientation.presenter(for: controller) === controller)
    }

    func testPresenterUsesTheOwningWindowRootViewController() throws {
        let root = UIViewController()
        let child = UIViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = root
        root.addChild(child)
        root.view.addSubview(child.view)
        child.didMove(toParent: root)
        try XCTSkipIf(child.view.window == nil, "Detached UIWindow did not publish view.window")

        XCTAssertTrue(SceneInterfaceOrientation.presenter(for: child) === root)
    }

    func testBackgroundRefreshTaskIdentifierIsDeclaredInInfoPlist() {
        let identifiers = Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String]
        XCTAssertEqual(identifiers, [AppDelegate.backgroundRefreshTaskIdentifier])
    }
}
