import Foundation
import ObjectiveC
import UIKit

private var barButtonChromeStampKey: UInt8 = 0
private var buttonPlateStampKey: UInt8 = 0
private var toolbarStampKey: UInt8 = 0
private var plainBackControlKey: UInt8 = 0

private final class BarButtonChromeStamp {
    var resolvedTint: UIColor
    var clearedBackground: Bool
    var demotedProminent: Bool

    init(resolvedTint: UIColor, clearedBackground: Bool, demotedProminent: Bool) {
        self.resolvedTint = resolvedTint
        self.clearedBackground = clearedBackground
        self.demotedProminent = demotedProminent
    }
}

private final class ButtonPlateStamp {
    var theme: Int
    var resolvedTint: UIColor?
    /// Stops a layout loop if UIKit puts the glass plate back after we clear it.
    var failedAttempts: Int

    init(theme: Int, resolvedTint: UIColor?, failedAttempts: Int) {
        self.theme = theme
        self.resolvedTint = resolvedTint
        self.failedAttempts = failedAttempts
    }
}

private final class ToolbarStamp {
    let theme: Int
    let resolvedTint: UIColor

    init(theme: Int, resolvedTint: UIColor) {
        self.theme = theme
        self.resolvedTint = resolvedTint
    }
}

class ThemeUIUtils {

    /// Keep system-rendered controls in the same light/dark appearance as the selected app theme.
    class func applyInterfaceStyle(to controller: UIViewController) {
        switch Theme.currentTheme() {
        case .Light, .OctoPrint:
            controller.overrideUserInterfaceStyle = .light
        case .Dark, .Orange:
            controller.overrideUserInterfaceStyle = .dark
        case .System:
            controller.overrideUserInterfaceStyle = .unspecified
        }
    }

    class func applyTheme(navigationController: UINavigationController, octoPrintColor: String?) {
        applyInterfaceStyle(to: navigationController)
        let theme = Theme.currentTheme()
        let titleColor = theme.navigationTitleColor(octoPrintColor: octoPrintColor)
        let actionColor = theme.navigationTintColor(octoPrintColor: octoPrintColor)

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = theme.navigationTopColor(octoPrintColor: octoPrintColor)
        appearance.titleTextAttributes = [.foregroundColor: titleColor]
        appearance.largeTitleTextAttributes = [.foregroundColor: titleColor]

        // Plain, Done, and Back share one borderless title color. A clear background image
        // keeps iOS 15–25 from painting a button fill, and gives iOS 26 one less plate to draw.
        applyTitleColors(appearance.buttonAppearance, tint: actionColor, semibold: false)
        applyTitleColors(appearance.doneButtonAppearance, tint: actionColor, semibold: false)
        applyTitleColors(appearance.backButtonAppearance, tint: actionColor, semibold: false)
        if #available(iOS 26.0, *) {
            // Done and Prominent are the same style on iOS 26. Both need the plain title color
            // in case a Save button is still rendered with the prominent appearance.
            applyTitleColors(appearance.prominentButtonAppearance, tint: actionColor, semibold: true)
        }

        let bar = navigationController.navigationBar
        bar.standardAppearance = appearance
        bar.scrollEdgeAppearance = appearance
        bar.compactAppearance = appearance
        bar.compactScrollEdgeAppearance = appearance
        bar.tintColor = actionColor
        // Buttons that already have an explicit tint keep it until the next layout.
        // Recolor them now so a theme change is visible without waiting for that pass.
        styleNavigationButtons(on: bar, tint: actionColor)
        styleSearchBarButtons()
        for controller in navigationController.viewControllers where controller.isViewLoaded {
            styleContentButtons(in: controller.view)
        }
        bar.layoutIfNeeded()
        if #available(iOS 26.0, *), let navigation = navigationController as? NavigationController {
            navigation.installPlainBackButtons()
        }
    }

    class func styleNavigationButtons(on navigationBar: UINavigationBar, tint: UIColor) {
        let traits = navigationBar.traitCollection
        let resolvedTint = tint.resolvedColor(with: traits)
        for item in navigationBar.items ?? [] {
            var buttons = (item.leftBarButtonItems ?? []) + (item.rightBarButtonItems ?? [])
            if let backButton = item.backBarButtonItem {
                buttons.append(backButton)
            }
            for button in buttons {
                styleBarButtonItem(button, tint: tint, resolvedTint: resolvedTint, isBack: button === item.backBarButtonItem)
            }
        }
        if #available(iOS 26.0, *) {
            // hidesSharedBackground on the model item often never reaches the back button UIKit already drew.
            flattenBarButtonPlates(in: navigationBar, tint: tint, resolvedTint: resolvedTint)
        }
    }

    /// Cancel and other search-bar actions follow the content tint, without a glass plate.
    class func styleSearchBarButtons() {
        let tint = Theme.currentTheme().tintColor()
        let proxy = UIBarButtonItem.appearance(whenContainedInInstancesOf: [UISearchBar.self])
        proxy.setTitleTextAttributes([.foregroundColor: tint], for: .normal)
        proxy.setTitleTextAttributes([.foregroundColor: color(tint, alpha: 0.7)], for: .highlighted)
        proxy.setTitleTextAttributes([.foregroundColor: color(tint, alpha: 0.35)], for: .disabled)
        let image = clearBarButtonBackground
        for metrics in [UIBarMetrics.default, .compact, .defaultPrompt, .compactPrompt] {
            proxy.setBackgroundImage(image, for: .normal, barMetrics: metrics)
            proxy.setBackgroundImage(image, for: .highlighted, barMetrics: metrics)
            proxy.setBackgroundImage(image, for: .disabled, barMetrics: metrics)
        }
    }

    /// Keyboard toolbars use the page colors. Nav-bar action colors stay on the navigation bar.
    class func styleToolbar(_ toolbar: UIToolbar) {
        let theme = Theme.currentTheme()
        let tint = theme.tintColor()
        let traits = toolbar.traitCollection
        let resolvedTint = tint.resolvedColor(with: traits)
        let stamp = objc_getAssociatedObject(toolbar, &toolbarStampKey) as? ToolbarStamp
        if stamp?.theme != theme.rawValue || stamp?.resolvedTint != resolvedTint {
            let appearance = UIToolbarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = theme.backgroundColor()
            applyTitleColors(appearance.buttonAppearance, tint: tint, semibold: false)
            applyTitleColors(appearance.doneButtonAppearance, tint: tint, semibold: false)
            if #available(iOS 26.0, *) {
                applyTitleColors(appearance.prominentButtonAppearance, tint: tint, semibold: true)
            }
            toolbar.standardAppearance = appearance
            toolbar.compactAppearance = appearance
            toolbar.scrollEdgeAppearance = appearance
            toolbar.compactScrollEdgeAppearance = appearance
            toolbar.tintColor = tint
            toolbar.isTranslucent = false
            objc_setAssociatedObject(toolbar, &toolbarStampKey, ToolbarStamp(theme: theme.rawValue, resolvedTint: resolvedTint), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        for item in toolbar.items ?? [] {
            styleBarButtonItem(item, tint: tint, resolvedTint: resolvedTint, isBack: false)
        }
        if #available(iOS 26.0, *) {
            flattenBarButtonPlates(in: toolbar, tint: tint, resolvedTint: resolvedTint)
        }
    }

    /// Title-only system buttons take the content tint. Image buttons keep their artwork color.
    /// iOS 26 glass plates are removed from both.
    class func styleContentButtons(in root: UIView) {
        styleContentTree(root, tint: Theme.currentTheme().tintColor())
    }

    /// Status-bar icons need to contrast with the navigation bar. OctoPrint page content
    /// stays light, while several printer colors paint a dark bar with a white title.
    class func preferredStatusBarStyle(octoPrintColor: String?, traits: UITraitCollection) -> UIStatusBarStyle {
        let barColor = Theme.currentTheme().navigationTopColor(octoPrintColor: octoPrintColor)
        return isLightBar(barColor, traits: traits) ? .darkContent : .lightContent
    }

    private class func applyTitleColors(_ appearance: UIBarButtonItemAppearance, tint: UIColor, semibold: Bool) {
        func attributes(alpha: CGFloat) -> [NSAttributedString.Key: Any] {
            var value: [NSAttributedString.Key: Any] = [.foregroundColor: alpha == 1 ? tint : color(tint, alpha: alpha)]
            if semibold {
                value[.font] = semiboldButtonFont()
            }
            return value
        }
        appearance.normal.titleTextAttributes = attributes(alpha: 1)
        appearance.highlighted.titleTextAttributes = attributes(alpha: 0.7)
        appearance.disabled.titleTextAttributes = attributes(alpha: 0.35)
        appearance.focused.titleTextAttributes = attributes(alpha: 1)
        let image = clearBarButtonBackground
        appearance.normal.backgroundImage = image
        appearance.highlighted.backgroundImage = image
        appearance.disabled.backgroundImage = image
        appearance.focused.backgroundImage = image
    }

    private class func styleBarButtonItem(_ button: UIBarButtonItem, tint: UIColor, resolvedTint: UIColor, isBack: Bool) {
        let stamp = objc_getAssociatedObject(button, &barButtonChromeStampKey) as? BarButtonChromeStamp
        var demoted = stamp?.demotedProminent ?? false
        var needsGlassFlags = false
        var needsDemote = false
        if #available(iOS 26.0, *) {
            needsGlassFlags = !button.hidesSharedBackground || button.sharesBackground
            // .done is an alias of .prominent on iOS 26, so Save was drawing a filled capsule.
            needsDemote = button.style == .prominent
        }
        // A static theme color can match the dynamic System tint in the current
        // appearance and still diverge in the other one. Compare both.
        let tracksInstalledTint = colorTracksAppearance(button.tintColor, like: tint)
        let needsAttributes = demoted && (stamp?.resolvedTint != resolvedTint || !tracksInstalledTint)
        let needsTint = !tracksInstalledTint
        let needsClear = stamp?.clearedBackground != true
        if !needsGlassFlags && !needsDemote && !needsAttributes && !needsTint && !needsClear {
            return
        }

        if #available(iOS 26.0, *) {
            if !button.hidesSharedBackground {
                button.hidesSharedBackground = true
            }
            if button.sharesBackground {
                button.sharesBackground = false
            }
            if needsDemote || needsAttributes {
                button.style = .plain
                let font = semiboldButtonFont()
                button.setTitleTextAttributes([.foregroundColor: tint, .font: font], for: .normal)
                button.setTitleTextAttributes([.foregroundColor: color(tint, alpha: 0.7), .font: font], for: .highlighted)
                button.setTitleTextAttributes([.foregroundColor: color(tint, alpha: 0.35), .font: font], for: .disabled)
                button.setTitleTextAttributes([.foregroundColor: tint, .font: font], for: .focused)
                demoted = true
            }
        }

        if needsClear {
            let image = clearBarButtonBackground
            let states: [UIControl.State] = [.normal, .highlighted, .disabled, .focused]
            let metrics: [UIBarMetrics] = [.default, .compact, .defaultPrompt, .compactPrompt]
            for state in states {
                for metric in metrics {
                    button.setBackgroundImage(image, for: state, barMetrics: metric)
                    if isBack {
                        button.setBackButtonBackgroundImage(image, for: state, barMetrics: metric)
                    }
                }
            }
        }
        if needsTint {
            button.tintColor = tint
        }
        let updated = stamp ?? BarButtonChromeStamp(resolvedTint: resolvedTint, clearedBackground: true, demotedProminent: demoted)
        updated.resolvedTint = resolvedTint
        updated.clearedBackground = true
        updated.demotedProminent = demoted
        objc_setAssociatedObject(button, &barButtonChromeStampKey, updated, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    @available(iOS 26.0, *)
    private class func flattenBarButtonPlates(in root: UIView, tint: UIColor, resolvedTint: UIColor) {
        if let button = root as? UIButton {
            flattenBarButton(button, tint: tint, resolvedTint: resolvedTint)
        }
        for subview in root.subviews {
            flattenBarButtonPlates(in: subview, tint: tint, resolvedTint: resolvedTint)
        }
    }

    /// The plain back chevron is an original image in the navigation tint.
    /// Rewriting its configuration lets iOS 27 redraw that symbol in the label color.
    @available(iOS 26.0, *)
    class func protectPlainBackControl(_ button: UIButton) {
        objc_setAssociatedObject(button, &plainBackControlKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    @available(iOS 26.0, *)
    class func isPlainBackControlProtected(_ button: UIButton) -> Bool {
        objc_getAssociatedObject(button, &plainBackControlKey) as? Bool ?? false
    }

    @available(iOS 26.0, *)
    private class func flattenBarButton(_ button: UIButton, tint: UIColor, resolvedTint: UIColor) {
        if isPlainBackControlProtected(button) {
            return
        }
        let tintMatches = colorTracksAppearance(button.tintColor, like: tint)
        if button.configuration == nil {
            if !tintMatches {
                button.tintColor = tint
            }
            if button.layer.borderWidth != 0 {
                button.layer.borderWidth = 0
            }
            return
        }
        let foregroundMatches = colorTracksAppearance(button.configuration?.baseForegroundColor, like: tint)
        let plateClear = button.configuration.map { buttonPlateIsClear($0.background) && $0.baseBackgroundColor == .clear } ?? false
        if plateClear && foregroundMatches && tintMatches && button.layer.borderWidth == 0 {
            return
        }
        guard consumePlateAttempt(on: button, resolvedTint: resolvedTint) else {
            return
        }
        var config = button.configuration!
        // backgroundColor and strokeColor treat nil as "use the tint", so the plate has to be clear.
        config.background = clearButtonBackground()
        config.baseForegroundColor = tint
        config.baseBackgroundColor = .clear
        button.configuration = config
        button.tintColor = tint
        button.setTitleColor(tint, for: .normal)
        button.setTitleColor(color(tint, alpha: 0.7), for: .highlighted)
        button.setTitleColor(color(tint, alpha: 0.35), for: .disabled)
        button.layer.borderWidth = 0
    }

    private class func styleContentTree(_ view: UIView, tint: UIColor) {
        if view is UINavigationBar || view is UITabBar {
            return
        }
        if let toolbar = view as? UIToolbar {
            styleToolbar(toolbar)
            return
        }
        if let field = view as? UITextField, let toolbar = field.inputAccessoryView as? UIToolbar {
            styleToolbar(toolbar)
        } else if let textView = view as? UITextView, let toolbar = textView.inputAccessoryView as? UIToolbar {
            styleToolbar(toolbar)
        }
        if let button = view as? UIButton {
            styleContentButton(button, tint: tint)
        }
        for subview in view.subviews {
            styleContentTree(subview, tint: tint)
        }
    }

    private class func styleContentButton(_ button: UIButton, tint: UIColor) {
        // Colored artwork, camera scrims, and explicit title colors (Delete, Cancel) stay as designed.
        let hasOpaqueBackground = opaqueBackground(button.backgroundColor, traits: button.traitCollection)
        let hasBackgroundImage = button.backgroundImage(for: .normal) != nil
        let hasExplicitTitleColor = !isInheritedTitleColor(button.titleColor(for: .normal), tint: button.tintColor)
        let title = button.title(for: .normal) ?? button.currentTitle
        let hasTitle = !(title ?? "").isEmpty
        let shouldTint = button.buttonType == .system && hasTitle && !hasOpaqueBackground && !hasBackgroundImage && !hasExplicitTitleColor
        if shouldTint && !colorTracksAppearance(button.tintColor, like: tint) {
            button.tintColor = tint
        }
        guard #available(iOS 26.0, *), !hasOpaqueBackground, !hasBackgroundImage, button.configuration != nil else {
            return
        }
        let foreground = shouldTint ? tint : nil
        let traits = button.traitCollection
        let resolvedForeground = foreground?.resolvedColor(with: traits)
        let foregroundMatches = foreground == nil || colorTracksAppearance(button.configuration?.baseForegroundColor, like: foreground!)
        let plateClear = button.configuration.map { buttonPlateIsClear($0.background) && ($0.baseBackgroundColor == .clear || $0.baseBackgroundColor == nil) } ?? true
        if plateClear && foregroundMatches && button.layer.borderWidth == 0 {
            return
        }
        guard consumePlateAttempt(on: button, resolvedTint: resolvedForeground) else {
            return
        }
        var config = button.configuration!
        config.background = clearButtonBackground()
        if let foreground {
            config.baseForegroundColor = foreground
        }
        config.baseBackgroundColor = .clear
        button.configuration = config
        button.layer.borderWidth = 0
    }

    private class func buttonPlateIsClear(_ background: UIBackgroundConfiguration) -> Bool {
        return background.visualEffect == nil
            && background.strokeWidth == 0
            && background.image == nil
            && background.backgroundColor == .clear
    }

    /// Returns false after two failed clears for the same color, so a restored plate cannot loop layout.
    private class func consumePlateAttempt(on button: UIButton, resolvedTint: UIColor?) -> Bool {
        let theme = Theme.currentTheme().rawValue
        let stamp = objc_getAssociatedObject(button, &buttonPlateStampKey) as? ButtonPlateStamp
            ?? ButtonPlateStamp(theme: theme, resolvedTint: nil, failedAttempts: 0)
        if stamp.theme != theme || stamp.resolvedTint != resolvedTint {
            stamp.theme = theme
            stamp.resolvedTint = resolvedTint
            stamp.failedAttempts = 0
        }
        stamp.failedAttempts += 1
        objc_setAssociatedObject(button, &buttonPlateStampKey, stamp, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return stamp.failedAttempts <= 2
    }

    /// iOS 27 reports an unset system-button title color as `systemBlue`, which is also the
    /// button's tint. A color chosen in the storyboard, such as Cancel's red, does not follow that tint.
    private class func isInheritedTitleColor(_ color: UIColor?, tint: UIColor?) -> Bool {
        guard let color else {
            return true
        }
        if colorTracksAppearance(color, like: .systemBlue) {
            return true
        }
        if let tint, colorTracksAppearance(color, like: tint) {
            return true
        }
        return false
    }

    /// True when `current` resolves like `tint` in both light and dark.
    /// Matching only the appearance on screen hides a System tint behind a static theme color.
    class func colorTracksAppearance(_ current: UIColor?, like tint: UIColor) -> Bool {
        guard let current else {
            return false
        }
        let light = UITraitCollection(userInterfaceStyle: .light)
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        return sameColor(current.resolvedColor(with: light), tint.resolvedColor(with: light))
            && sameColor(current.resolvedColor(with: dark), tint.resolvedColor(with: dark))
    }

    class func sameColor(_ lhs: UIColor?, _ rhs: UIColor?) -> Bool {
        guard let lhs, let rhs else {
            return lhs == nil && rhs == nil
        }
        var leftRed: CGFloat = 0
        var leftGreen: CGFloat = 0
        var leftBlue: CGFloat = 0
        var leftAlpha: CGFloat = 0
        var rightRed: CGFloat = 0
        var rightGreen: CGFloat = 0
        var rightBlue: CGFloat = 0
        var rightAlpha: CGFloat = 0
        guard lhs.getRed(&leftRed, green: &leftGreen, blue: &leftBlue, alpha: &leftAlpha),
              rhs.getRed(&rightRed, green: &rightGreen, blue: &rightBlue, alpha: &rightAlpha) else {
            return lhs == rhs
        }
        let tolerance: CGFloat = 1.0 / 255.0
        return abs(leftRed - rightRed) <= tolerance
            && abs(leftGreen - rightGreen) <= tolerance
            && abs(leftBlue - rightBlue) <= tolerance
            && abs(leftAlpha - rightAlpha) <= tolerance
    }

    private class func opaqueBackground(_ color: UIColor?, traits: UITraitCollection) -> Bool {
        guard let color else {
            return false
        }
        return color.resolvedColor(with: traits).cgColor.alpha > 0.01
    }

    private class func clearButtonBackground() -> UIBackgroundConfiguration {
        var background = UIBackgroundConfiguration.clear()
        background.backgroundColor = .clear
        background.visualEffect = nil
        background.image = nil
        background.strokeWidth = 0
        background.strokeColor = .clear
        return background
    }

    private static let clearBarButtonBackground: UIImage = {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1), format: format)
        let image = renderer.image { _ in
            UIColor.clear.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return image.resizableImage(withCapInsets: .zero, resizingMode: .stretch)
    }()

    private class func semiboldButtonFont() -> UIFont {
        let base = UIFont.systemFont(ofSize: UIFont.buttonFontSize, weight: .semibold)
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: base)
    }

    private class func color(_ color: UIColor, alpha: CGFloat) -> UIColor {
        UIColor { traits in
            color.resolvedColor(with: traits).withAlphaComponent(alpha)
        }
    }

    private class func isLightBar(_ color: UIColor, traits: UITraitCollection) -> Bool {
        let resolved = color.resolvedColor(with: traits)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            var white: CGFloat = 0
            if resolved.getWhite(&white, alpha: nil) {
                return white >= 0.5
            }
            return true
        }
        func linear(_ channel: CGFloat) -> CGFloat {
            let value = min(max(channel, 0), 1)
            if value <= 0.04045 {
                return value / 12.92
            }
            return pow((value + 0.055) / 1.055, 2.4)
        }
        let luminance = (0.2126 * linear(red)) + (0.7152 * linear(green)) + (0.0722 * linear(blue))
        return luminance >= 0.5
    }

    class func applyTheme(tabBar: UITabBar) {
        let theme = Theme.currentTheme()
        let appearance = UITabBarAppearance()
        if #available(iOS 26.0, *) {
            // The system tab menu is the floating platter. A painted bar behind it
            // shows a second menu when a tab is selected.
            appearance.configureWithTransparentBackground()
        } else {
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = theme.tabBarColor()
        }
        for items in [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance] {
            items.normal.iconColor = theme.textColor()
            items.normal.titleTextAttributes = [.foregroundColor: theme.textColor()]
            items.selected.iconColor = theme.tintColor()
            items.selected.titleTextAttributes = [.foregroundColor: theme.tintColor()]
        }
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = theme.tintColor()
        tabBar.unselectedItemTintColor = theme.textColor()
        if #available(iOS 26.0, *) {
            tabBar.isTranslucent = true
            tabBar.backgroundColor = nil
            tabBar.barTintColor = nil
        } else {
            tabBar.isTranslucent = false
            tabBar.barTintColor = theme.tabBarColor()
        }
    }
    
    class func themeCell(cell: UITableViewCell) {
        let theme = Theme.currentTheme()
        let textColor = theme.textColor()
        
        cell.backgroundColor = theme.cellBackgroundColor()
        cell.textLabel?.textColor = textColor
        cell.detailTextLabel?.textColor = textColor
        styleContentButtons(in: cell)
    }
    
    class func applyTheme(table: UITableView, staticCells: Bool) {
        let theme = Theme.currentTheme()
        table.separatorColor = theme.separatorColor()
        table.sectionIndexBackgroundColor = theme.backgroundColor()
        table.backgroundColor = staticCells ? theme.backgroundColor() : theme.cellBackgroundColor()
    }
    
    class func applyTheme(refreshControl: UIRefreshControl) {
        let theme = Theme.currentTheme()
        let textLabelColor = theme.labelColor()

        refreshControl.tintColor = textLabelColor
        refreshControl.attributedTitle = NSAttributedString(string: NSLocalizedString("Pull down to refresh", comment: ""), attributes: [.foregroundColor : textLabelColor])
    }
}
