import UIKit
import XCTest
@testable import OctoPod

final class PlainBackButtonTests: XCTestCase {

    func testBackChevronImageUsesTheNavigationTint() throws {
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("The plain back chevron exists on iOS 26 and later")
        }
        let blue = UIColor(red: 0, green: 122.4 / 255, blue: 1, alpha: 1)
        let image = try XCTUnwrap(NavigationController.backChevronImage(tint: blue))
        XCTAssertEqual(image.renderingMode, .alwaysOriginal)

        let sampled = try XCTUnwrap(averageOpaqueColor(image))
        XCTAssertLessThan(sampled.red, 0.2)
        XCTAssertGreaterThan(sampled.blue, 0.75)
        XCTAssertGreaterThan(sampled.blue, sampled.red + 0.4)

        let white = try XCTUnwrap(NavigationController.backChevronImage(tint: .white))
        let whiteSample = try XCTUnwrap(averageOpaqueColor(white))
        XCTAssertGreaterThan(whiteSample.red, 0.9)
        XCTAssertGreaterThan(whiteSample.green, 0.9)
        XCTAssertGreaterThan(whiteSample.blue, 0.9)
    }

    func testPlainBackControlKeepsChevronAndTitleOnTheSameTint() throws {
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("The plain back control exists on iOS 26 and later")
        }
        let tint = UIColor(red: 0, green: 122.4 / 255, blue: 1, alpha: 1)
        let button = NavigationController.plainBackControl(title: "Settings", tint: tint, traits: .current)
        XCTAssertEqual(button.accessibilityLabel, "Settings")
        XCTAssertEqual(button.configuration?.title, "Settings")
        XCTAssertEqual(button.configuration?.image?.renderingMode, .alwaysOriginal)
        XCTAssertEqual(button.configuration?.baseForegroundColor?.resolvedColor(with: .current), tint.resolvedColor(with: .current))
        XCTAssertEqual(button.configuration?.baseBackgroundColor, .clear)
        XCTAssertTrue(ThemeUIUtils.isPlainBackControlProtected(button))

        let chevronOnly = NavigationController.plainBackControl(title: nil, tint: tint, traits: .current)
        XCTAssertEqual(chevronOnly.accessibilityLabel, "Back")
        XCTAssertNil(chevronOnly.configuration?.title)
        XCTAssertEqual(chevronOnly.configuration?.image?.renderingMode, .alwaysOriginal)
    }

    func testExistingControlFollowsSystemAppearanceInBothDirections() throws {
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("The plain back control exists on iOS 26 and later")
        }
        let system = Theme.ThemeChoice.System.navigationTintColor(octoPrintColor: nil)
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        let light = UITraitCollection(userInterfaceStyle: .light)
        let button = NavigationController.plainBackControl(title: "Settings", tint: system, traits: dark)
        assertChevron(button, isBlack: true)

        NavigationController.updatePlainBackControl(button, title: "Settings", tint: system, traits: light)
        assertChevron(button, isBlue: true)
        XCTAssertEqual(button.configuration?.baseForegroundColor?.resolvedColor(with: light), system.resolvedColor(with: light))

        NavigationController.updatePlainBackControl(button, title: "Settings", tint: system, traits: dark)
        assertChevron(button, isBlack: true)
        XCTAssertEqual(button.configuration?.baseForegroundColor?.resolvedColor(with: dark), system.resolvedColor(with: dark))
    }

    func testExistingControlFollowsSystemPrinterColorInBothDirections() throws {
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("The plain back control exists on iOS 26 and later")
        }
        // Green keeps the palette rule: dark OS uses the white title color, light OS uses black.
        let system = Theme.ThemeChoice.System.navigationTintColor(octoPrintColor: "green")
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        let light = UITraitCollection(userInterfaceStyle: .light)
        let button = NavigationController.plainBackControl(title: "Settings", tint: system, traits: light)
        assertChevron(button, isBlack: true)

        NavigationController.updatePlainBackControl(button, title: "Settings", tint: system, traits: dark)
        assertChevron(button, isWhite: true)

        NavigationController.updatePlainBackControl(button, title: "Settings", tint: system, traits: light)
        assertChevron(button, isBlack: true)
    }

    /// The same installed control, inside a navigation bar, through both OS appearance
    /// directions. Resolving the dynamic tint under a trait collection that is still
    /// the previous appearance leaves the baked chevron behind the title.
    func testInstalledControlFollowsSystemAppearanceInBothDirections() throws {
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("The plain back control exists on iOS 26 and later")
        }
        let previous = Theme.currentTheme()
        defer { Theme.switchTheme(choice: previous) }
        Theme.switchTheme(choice: .System)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 1024, height: 768))
        window.windowScene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let root = UIViewController()
        root.navigationItem.title = "Settings"
        let page = UIViewController()
        let navigation = NavigationController(rootViewController: root)
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        navigation.pushViewController(page, animated: false)

        window.overrideUserInterfaceStyle = .dark
        ThemeUIUtils.applyTheme(navigationController: navigation, octoPrintColor: nil)
        navigation.view.layoutIfNeeded()

        func settle(expecting style: UIUserInterfaceStyle) -> UIButton {
            let deadline = Date().addingTimeInterval(0.6)
            var button = page.navigationItem.leftBarButtonItem?.customView as? UIButton ?? UIButton()
            while Date() < deadline {
                navigation.view.setNeedsLayout()
                navigation.view.layoutIfNeeded()
                RunLoop.current.run(until: Date().addingTimeInterval(0.05))
                button = page.navigationItem.leftBarButtonItem?.customView as? UIButton ?? button
                if navigation.traitCollection.userInterfaceStyle == style,
                   navigation.navigationBar.traitCollection.userInterfaceStyle == style,
                   button.traitCollection.userInterfaceStyle == style {
                    break
                }
            }
            let styles = "nav=\(navigation.traitCollection.userInterfaceStyle.rawValue) bar=\(navigation.navigationBar.traitCollection.userInterfaceStyle.rawValue) button=\(button.traitCollection.userInterfaceStyle.rawValue)"
            XCTAssertEqual(navigation.traitCollection.userInterfaceStyle, style, styles)
            XCTAssertEqual(button.traitCollection.userInterfaceStyle, style, styles)
            return button
        }

        let darkButton = settle(expecting: .dark)
        assertChevron(darkButton, isBlack: true)
        assertRenderedChevron(darkButton, isBlack: true, label: "dark")

        // An OS appearance change does not run applyTheme. The installed control has to follow it.
        window.overrideUserInterfaceStyle = .light
        let lightButton = settle(expecting: .light)
        assertChevron(lightButton, isBlue: true)
        assertRenderedChevron(lightButton, isBlue: true, label: "light")

        window.overrideUserInterfaceStyle = .dark
        let again = settle(expecting: .dark)
        assertChevron(again, isBlack: true)
        assertRenderedChevron(again, isBlack: true, label: "dark again")
    }

    /// System's light resolution is the same blue as an explicit Light theme.
    /// Skipping that update would leave the dynamic color installed, so a later
    /// dark appearance would turn the chevron black.
    func testInstalledControlSwitchesBetweenSystemAndExplicitThemes() throws {
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("The plain back control exists on iOS 26 and later")
        }
        let previous = Theme.currentTheme()
        defer { Theme.switchTheme(choice: previous) }
        Theme.switchTheme(choice: .System)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 1024, height: 768))
        window.windowScene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let root = UIViewController()
        root.navigationItem.title = "Settings"
        let page = UIViewController()
        let navigation = NavigationController(rootViewController: root)
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        navigation.pushViewController(page, animated: false)

        window.overrideUserInterfaceStyle = .light
        ThemeUIUtils.applyTheme(navigationController: navigation, octoPrintColor: nil)
        navigation.view.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        let button = try XCTUnwrap(page.navigationItem.leftBarButtonItem?.customView as? UIButton)
        assertChevron(button, isBlue: true)

        Theme.switchTheme(choice: .Light)
        ThemeUIUtils.applyTheme(navigationController: navigation, octoPrintColor: nil)
        navigation.view.layoutIfNeeded()
        let lightTheme = Theme.ThemeChoice.Light.navigationTintColor(octoPrintColor: nil)
        let darkTraits = UITraitCollection(userInterfaceStyle: .dark)
        XCTAssertEqual(button.configuration?.baseForegroundColor?.resolvedColor(with: darkTraits), lightTheme.resolvedColor(with: darkTraits))
        assertChevron(button, isBlue: true)

        // Light forces a light interface, so the OS appearance cannot turn this chevron black.
        window.overrideUserInterfaceStyle = .dark
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        navigation.view.layoutIfNeeded()
        assertChevron(button, isBlue: true)

        Theme.switchTheme(choice: .System)
        window.overrideUserInterfaceStyle = .dark
        ThemeUIUtils.applyTheme(navigationController: navigation, octoPrintColor: nil)
        navigation.view.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        assertChevron(button, isBlack: true)
    }

    func testSwitchingBetweenSystemAndExplicitThemesRefreshesWhenResolvedColorsMatch() throws {
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("The plain back control exists on iOS 26 and later")
        }
        let system = Theme.ThemeChoice.System.navigationTintColor(octoPrintColor: nil)
        let lightTheme = Theme.ThemeChoice.Light.navigationTintColor(octoPrintColor: nil)
        let darkTheme = Theme.ThemeChoice.Dark.navigationTintColor(octoPrintColor: nil)
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        let light = UITraitCollection(userInterfaceStyle: .light)

        let button = NavigationController.plainBackControl(title: "Settings", tint: system, traits: dark)
        assertChevron(button, isBlack: true)

        // Light's static blue matches System's light resolution, but System's dark resolution is black.
        NavigationController.updatePlainBackControl(button, title: "Settings", tint: lightTheme, traits: light)
        assertChevron(button, isBlue: true)
        XCTAssertEqual(button.configuration?.baseForegroundColor?.resolvedColor(with: dark), lightTheme.resolvedColor(with: dark))

        // The explicit Light color stays blue when the OS becomes dark.
        NavigationController.updatePlainBackControl(button, title: "Settings", tint: lightTheme, traits: dark)
        assertChevron(button, isBlue: true)

        // System under dark is black. Explicit Dark is blue even though the OS appearance did not change.
        NavigationController.updatePlainBackControl(button, title: "Settings", tint: system, traits: dark)
        assertChevron(button, isBlack: true)
        NavigationController.updatePlainBackControl(button, title: "Settings", tint: darkTheme, traits: dark)
        assertChevron(button, isBlue: true)
        XCTAssertEqual(button.configuration?.baseForegroundColor?.resolvedColor(with: light), darkTheme.resolvedColor(with: light))
    }

    private func assertRenderedChevron(_ button: UIButton, isBlack: Bool = false, isBlue: Bool = false, isWhite: Bool = false, label: String) {
        button.sizeToFit()
        let size = CGSize(width: max(button.bounds.width, 44), height: max(button.bounds.height, 32))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            button.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
        guard let cgImage = rendered.cgImage else {
            XCTFail("\(label) did not render")
            return
        }
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var data = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let context = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            XCTFail("\(label) context failed")
            return
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        // The chevron sits in the leading portion. The title fills the rest.
        let chevronWidth = min(width / 4, 36)
        var red = 0.0
        var green = 0.0
        var blue = 0.0
        var count = 0.0
        for y in 0..<height {
            for x in 0..<chevronWidth {
                let index = y * bytesPerRow + x * bytesPerPixel
                let alpha = Double(data[index + 3]) / 255
                if alpha >= 0.5 {
                    red += Double(data[index]) / 255 / alpha
                    green += Double(data[index + 1]) / 255 / alpha
                    blue += Double(data[index + 2]) / 255 / alpha
                    count += 1
                }
            }
        }
        XCTAssertGreaterThan(count, 0, "\(label) chevron had no opaque pixels")
        guard count > 0 else {
            return
        }
        let sampled = (red: CGFloat(red / count), green: CGFloat(green / count), blue: CGFloat(blue / count))
        if isBlack {
            XCTAssertLessThan(sampled.red, 0.25, "\(label) red \(sampled.red)")
            XCTAssertLessThan(sampled.green, 0.25, "\(label) green \(sampled.green)")
            XCTAssertLessThan(sampled.blue, 0.25, "\(label) blue \(sampled.blue)")
        }
        if isBlue {
            XCTAssertLessThan(sampled.red, 0.35, "\(label) red \(sampled.red)")
            XCTAssertGreaterThan(sampled.blue, 0.6, "\(label) blue \(sampled.blue)")
            XCTAssertGreaterThan(sampled.blue, sampled.red + 0.3, "\(label) \(sampled)")
        }
        if isWhite {
            XCTAssertGreaterThan(sampled.red, 0.8, "\(label) red \(sampled.red)")
            XCTAssertGreaterThan(sampled.green, 0.8, "\(label) green \(sampled.green)")
            XCTAssertGreaterThan(sampled.blue, 0.8, "\(label) blue \(sampled.blue)")
        }
    }

    private func assertChevron(_ button: UIButton, isBlack: Bool = false, isBlue: Bool = false, isWhite: Bool = false) {
        let sampled = averageOpaqueColor(button.configuration?.image ?? UIImage())
        XCTAssertNotNil(sampled)
        guard let sampled else {
            return
        }
        if isBlack {
            XCTAssertLessThan(sampled.red, 0.15)
            XCTAssertLessThan(sampled.green, 0.15)
            XCTAssertLessThan(sampled.blue, 0.15)
        }
        if isBlue {
            XCTAssertLessThan(sampled.red, 0.2)
            XCTAssertGreaterThan(sampled.blue, 0.75)
            XCTAssertGreaterThan(sampled.blue, sampled.red + 0.4)
        }
        if isWhite {
            XCTAssertGreaterThan(sampled.red, 0.9)
            XCTAssertGreaterThan(sampled.green, 0.9)
            XCTAssertGreaterThan(sampled.blue, 0.9)
        }
    }

    private func averageOpaqueColor(_ image: UIImage) -> (red: CGFloat, green: CGFloat, blue: CGFloat)? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale > 0 ? image.scale : 1
        format.opaque = false
        let rendered = UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        guard let cgImage = rendered.cgImage else {
            return nil
        }
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else {
            return nil
        }
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var data = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let context = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var red = 0.0
        var green = 0.0
        var blue = 0.0
        var count = 0.0
        var index = 0
        while index < data.count {
            let alpha = Double(data[index + 3]) / 255
            if alpha >= 0.5 {
                red += Double(data[index]) / 255 / alpha
                green += Double(data[index + 1]) / 255 / alpha
                blue += Double(data[index + 2]) / 255 / alpha
                count += 1
            }
            index += 4
        }
        guard count > 0 else {
            return nil
        }
        return (CGFloat(red / count), CGFloat(green / count), CGFloat(blue / count))
    }
}

/// Content and bar-button tints must follow System after an explicit theme whose
/// current appearance happens to resolve to the same color.
final class ContentTintTrackingTests: XCTestCase {

    private let lightTraits = UITraitCollection(userInterfaceStyle: .light)
    private let darkTraits = UITraitCollection(userInterfaceStyle: .dark)

    func testPrintButtonFollowsSystemAfterLightThemeWhileAppearanceIsLight() {
        let previous = Theme.currentTheme()
        defer { Theme.switchTheme(choice: previous) }
        let button = styledTitleButton("Print", appearance: .light)

        Theme.switchTheme(choice: .Light)
        ThemeUIUtils.styleContentButtons(in: button)
        Theme.switchTheme(choice: .System)
        ThemeUIUtils.styleContentButtons(in: button)

        let system = Theme.ThemeChoice.System.tintColor()
        let light = Theme.ThemeChoice.Light.tintColor()
        XCTAssertEqual(button.tintColor?.resolvedColor(with: darkTraits), system.resolvedColor(with: darkTraits))
        XCTAssertNotEqual(button.tintColor?.resolvedColor(with: darkTraits), light.resolvedColor(with: darkTraits))
        XCTAssertTrue(ThemeUIUtils.colorTracksAppearance(button.titleColor(for: .normal), like: system))
        XCTAssertFalse(ThemeUIUtils.colorTracksAppearance(button.titleColor(for: .normal), like: light))
    }

    func testConfiguredPrintButtonReplacesStaticForeground() {
        guard #available(iOS 26.0, *) else {
            return
        }
        let previous = Theme.currentTheme()
        defer { Theme.switchTheme(choice: previous) }
        let button = styledTitleButton("Print", appearance: .light)
        var config = UIButton.Configuration.plain()
        config.title = "Print"
        config.baseForegroundColor = Theme.ThemeChoice.Light.tintColor()
        button.configuration = config
        button.tintColor = Theme.ThemeChoice.Light.tintColor()

        Theme.switchTheme(choice: .System)
        // themeLabels assigns the dynamic tint and does not touch the configuration.
        button.tintColor = Theme.ThemeChoice.System.tintColor()
        ThemeUIUtils.styleContentButtons(in: button)

        let system = Theme.ThemeChoice.System.tintColor()
        let light = Theme.ThemeChoice.Light.tintColor()
        let foreground = button.configuration?.baseForegroundColor
        XCTAssertEqual(foreground?.resolvedColor(with: darkTraits), system.resolvedColor(with: darkTraits))
        XCTAssertNotEqual(foreground?.resolvedColor(with: darkTraits), light.resolvedColor(with: darkTraits))
    }

    func testPrintButtonFollowsSystemAfterDarkThemeWhileAppearanceIsDark() {
        let previous = Theme.currentTheme()
        defer { Theme.switchTheme(choice: previous) }
        let button = styledTitleButton("Pause", appearance: .dark)

        Theme.switchTheme(choice: .Dark)
        ThemeUIUtils.styleContentButtons(in: button)
        Theme.switchTheme(choice: .System)
        ThemeUIUtils.styleContentButtons(in: button)

        let system = Theme.ThemeChoice.System.tintColor()
        let dark = Theme.ThemeChoice.Dark.tintColor()
        XCTAssertEqual(button.tintColor?.resolvedColor(with: lightTraits), system.resolvedColor(with: lightTraits))
        XCTAssertNotEqual(button.tintColor?.resolvedColor(with: lightTraits), dark.resolvedColor(with: lightTraits))
        XCTAssertTrue(ThemeUIUtils.colorTracksAppearance(button.titleColor(for: .normal), like: system))
        XCTAssertFalse(ThemeUIUtils.colorTracksAppearance(button.titleColor(for: .normal), like: dark))
    }

    func testCancelKeepsItsExplicitRedTitle() {
        let previous = Theme.currentTheme()
        defer { Theme.switchTheme(choice: previous) }
        Theme.switchTheme(choice: .System)
        let button = styledTitleButton("Cancel", appearance: .light)
        let red = UIColor.systemRed
        button.setTitleColor(red, for: .normal)
        ThemeUIUtils.styleContentButtons(in: button)
        XCTAssertTrue(ThemeUIUtils.colorTracksAppearance(button.titleColor(for: .normal), like: red))
        XCTAssertFalse(ThemeUIUtils.colorTracksAppearance(button.tintColor, like: Theme.ThemeChoice.System.tintColor()))
        if #available(iOS 26.0, *), let foreground = button.configuration?.baseForegroundColor {
            XCTAssertTrue(ThemeUIUtils.colorTracksAppearance(foreground, like: red))
        }
    }

    func testSaveItemFollowsSystemNavigationTintWhenLightAppearanceMatches() {
        let previous = Theme.currentTheme()
        defer { Theme.switchTheme(choice: previous) }
        let item = UIBarButtonItem(title: "Save", style: .plain, target: nil, action: nil)
        let bar = UINavigationBar(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
        bar.overrideUserInterfaceStyle = .light
        let navItem = UINavigationItem(title: "Panel")
        navItem.rightBarButtonItem = item
        bar.setItems([navItem], animated: false)

        let light = Theme.ThemeChoice.Light.navigationTintColor(octoPrintColor: nil)
        let system = Theme.ThemeChoice.System.navigationTintColor(octoPrintColor: nil)
        ThemeUIUtils.styleNavigationButtons(on: bar, tint: light)
        ThemeUIUtils.styleNavigationButtons(on: bar, tint: system)

        XCTAssertEqual(item.tintColor?.resolvedColor(with: darkTraits), system.resolvedColor(with: darkTraits))
        XCTAssertNotEqual(item.tintColor?.resolvedColor(with: darkTraits), light.resolvedColor(with: darkTraits))
    }

    /// Matches a storyboard system button such as Print: a title, no explicit title color.
    private func styledTitleButton(_ title: String, appearance: UIUserInterfaceStyle) -> UIButton {
        let button = UIButton(type: .system)
        button.overrideUserInterfaceStyle = appearance
        button.setTitle(title, for: .normal)
        return button
    }
}
