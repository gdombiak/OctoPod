import XCTest
@testable import OctoPod

/// CamerasViewController installs its page-curl controller only while a printer
/// page exists. An empty UIPageViewController raises NSInternalInconsistencyException
/// ("No view controllers") when the iPad rotates.
final class CamerasPageControllerTests: PrinterManagerTestCase {

    private var window: UIWindow?
    private var cameras: CamerasViewControllerUnderTest?

    override func tearDownWithError() throws {
        window?.rootViewController = nil
        window?.isHidden = true
        window = nil
        cameras = nil
        try super.tearDownWithError()
    }

    func testEmptyPanelHasNoPageControllerInPortraitOrLandscape() {
        let cameras = showCameras()

        XCTAssertNil(pageController(in: cameras))
        XCTAssertTrue(cameras.pageControl.isHidden)

        resize(cameras, to: CGSize(width: 1024, height: 768))
        XCTAssertNil(pageController(in: cameras))

        resize(cameras, to: CGSize(width: 768, height: 1024))
        XCTAssertNil(pageController(in: cameras))
    }

    func testAddingPrinterInstallsCameraPageAndRemovingLastPrinterClearsIt() throws {
        let cameras = showCameras()
        XCTAssertTrue(printerManager.addPrinter(connectionType: .apiKey, name: "Bench", hostname: "http://127.0.0.1:9", apiKey: "key", username: nil, password: nil, headers: nil, position: 0, iCloudUpdate: false))

        cameras.viewWillAppear(false)

        let page = try XCTUnwrap(pageController(in: cameras))
        XCTAssertEqual(page.viewControllers?.count, 1)
        XCTAssertTrue(page.viewControllers?.first is CameraMJPEGEmbeddedViewController)
        XCTAssertTrue(page.parent === cameras)
        XCTAssertNil(page.dataSource)
        XCTAssertTrue(cameras.pageControl.isHidden)

        resize(cameras, to: CGSize(width: 1024, height: 768))
        XCTAssertEqual(page.viewControllers?.count, 1)

        let printer = try XCTUnwrap(printerManager.getPrinters().first)
        printerManager.deletePrinter(printer, context: printerManager.managedObjectContext)
        cameras.viewWillAppear(false)

        XCTAssertNil(pageController(in: cameras))
        XCTAssertTrue(cameras.pageControl.isHidden)
        resize(cameras, to: CGSize(width: 768, height: 1024))
        XCTAssertNil(pageController(in: cameras))
    }

    func testPrinterSelectedChangedWhileVisibleRefreshesTheInstalledPage() {
        let cameras = showCameras()
        XCTAssertTrue(printerManager.addPrinter(connectionType: .apiKey, name: "Bench", hostname: "http://127.0.0.1:9", apiKey: "key", username: nil, password: nil, headers: nil, position: 0, iCloudUpdate: false))

        cameras.printerSelectedChanged()
        let applied = expectation(description: "camera pages updated")
        DispatchQueue.main.async { applied.fulfill() }
        wait(for: [applied], timeout: 1)

        let page = pageController(in: cameras)
        XCTAssertEqual(page?.viewControllers?.count, 1)
        XCTAssertTrue(page?.viewControllers?.first is CameraMJPEGEmbeddedViewController)

        let printer = printerManager.getPrinters().first!
        printerManager.deletePrinter(printer, context: printerManager.managedObjectContext)
        cameras.printerSelectedChanged()
        let cleared = expectation(description: "camera pages cleared")
        DispatchQueue.main.async { cleared.fulfill() }
        wait(for: [cleared], timeout: 1)

        XCTAssertNil(pageController(in: cameras))
    }

    func testTwoCamerasKeepPagingAndASingleCameraDisablesIt() throws {
        let cameras = showCameras()
        XCTAssertTrue(printerManager.addPrinter(connectionType: .apiKey, name: "Bench", hostname: "http://127.0.0.1:9", apiKey: "key", username: nil, password: nil, headers: nil, position: 0, iCloudUpdate: false))
        let printer = try XCTUnwrap(printerManager.getPrinters().first)
        XCTAssertTrue(printerManager.addMultiCamera(index: 0, name: "Main", cameraURL: "/webcam/?action=stream", cameraOrientation: 0, streamRatio: "16:9", context: printerManager.managedObjectContext, printer: printer))
        XCTAssertTrue(printerManager.addMultiCamera(index: 1, name: "Extra", cameraURL: "http://127.0.0.1:9/other", cameraOrientation: 0, streamRatio: "4:3", context: printerManager.managedObjectContext, printer: printer))

        cameras.viewWillAppear(false)

        let page = try XCTUnwrap(pageController(in: cameras))
        XCTAssertEqual(page.viewControllers?.count, 1)
        XCTAssertFalse(cameras.pageControl.isHidden)
        XCTAssertEqual(cameras.pageControl.numberOfPages, 2)
        XCTAssertTrue(page.dataSource === cameras)
        let shown = try XCTUnwrap(page.viewControllers?.first as? CameraEmbeddedViewController)
        let next = try XCTUnwrap(cameras.pageViewController(page, viewControllerAfter: shown) as? CameraEmbeddedViewController)
        let previous = try XCTUnwrap(cameras.pageViewController(page, viewControllerBefore: shown) as? CameraEmbeddedViewController)
        XCTAssertFalse(next === shown)
        XCTAssertTrue(next === previous)
        XCTAssertNotEqual(next.cameraURL, shown.cameraURL)

        let extra = try XCTUnwrap(printer.multiCameras?.first { $0.index_id == 1 })
        XCTAssertTrue(printerManager.deleteObject(extra, context: printerManager.managedObjectContext))
        cameras.viewWillAppear(false)

        XCTAssertTrue(page.parent === cameras)
        XCTAssertEqual(page.viewControllers?.count, 1)
        XCTAssertNil(page.dataSource)
        XCTAssertTrue(cameras.pageControl.isHidden)
        XCTAssertEqual(cameras.pageControl.numberOfPages, 1)
        resize(cameras, to: CGSize(width: 1024, height: 768))
        XCTAssertEqual(page.viewControllers?.count, 1)
    }

    private func showCameras() -> CamerasViewControllerUnderTest {
        let cameras = CamerasViewControllerUnderTest()
        cameras.printerManager = printerManager
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 768, height: 1024))
        window.rootViewController = cameras
        window.makeKeyAndVisible()
        cameras.view.layoutIfNeeded()
        self.window = window
        self.cameras = cameras
        return cameras
    }

    private func resize(_ cameras: CamerasViewController, to size: CGSize) {
        cameras.view.bounds = CGRect(origin: .zero, size: size)
        window?.bounds = cameras.view.bounds
        cameras.view.layoutIfNeeded()
    }

    private func pageController(in cameras: CamerasViewController) -> UIPageViewController? {
        let pages = cameras.children.compactMap { $0 as? UIPageViewController }
        XCTAssertLessThanOrEqual(pages.count, 1)
        return pages.first
    }
}

private final class CamerasViewControllerUnderTest: CamerasViewController {
    let ownedPageControl = UIPageControl()

    override func loadView() {
        let root = UIView(frame: CGRect(x: 0, y: 0, width: 768, height: 1024))
        ownedPageControl.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(ownedPageControl)
        NSLayoutConstraint.activate([
            ownedPageControl.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            ownedPageControl.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])
        view = root
    }

    override func viewDidLoad() {
        pageControl = ownedPageControl
        super.viewDidLoad()
    }
}
