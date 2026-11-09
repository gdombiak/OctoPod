import ObjectiveC
import UIKit

private var plainBackButtonKey: UInt8 = 0
private var renderedBackTintKey: UInt8 = 0
private var installedBackTintKey: UInt8 = 0

@available(iOS 26.0, *)
private extension UIBarButtonItem {
    /// Marks the plain back control this navigation controller installs.
    /// Screen-supplied left items, such as Cancel, stay untouched.
    var isPlainBackButton: Bool {
        get { objc_getAssociatedObject(self, &plainBackButtonKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &plainBackButtonKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

class NavigationController: UINavigationController, UINavigationControllerDelegate, UIGestureRecognizerDelegate, OctoPrintSettingsDelegate, DefaultPrinterManagerDelegate {

    lazy var printerManager: PrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).printerManager! }()
    lazy var octoprintClient: OctoPrintClient = { return (UIApplication.shared.delegate as! AppDelegate).octoprintClient }()
    lazy var defaultPrinterManager: DefaultPrinterManager = { return (UIApplication.shared.delegate as! AppDelegate).defaultPrinterManager }()
    private var coreDataAppearanceDeferred = false
    private var coreDataAppearanceSetupActive = false
    /// Printer color last applied to this bar. Nil until Core Data has provided one.
    private var navigationBarOctoPrintColor: String?
    /// One follow-up refresh after an appearance change, once child traits have caught up.
    private var plainBackRefreshPending = false

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(coreDataDidBecomeReady), name: AppDelegate.coreDataReadyNotification, object: nil)
        // Storyboard navigation controllers do not set a delegate. willShow themes page buttons
        // that are not navigation-bar items.
        if delegate == nil {
            delegate = self
        }
        if #available(iOS 26.0, *) {
            // A custom left item turns this gesture off. The plain back button below is that item.
            interactivePopGestureRecognizer?.delegate = self
            // System theme's navigation tint is dynamic. The title follows it on its own.
            // The chevron image does not, so refresh it when the OS appearance changes.
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (controller: Self, previous: UITraitCollection) in
                guard previous.userInterfaceStyle != controller.traitCollection.userInterfaceStyle else {
                    return
                }
                // The bar and the back button can still be on the previous style here.
                // Resolving against those traits bakes the old chevron and then skips
                // the real change. Refresh once those children have the new style.
                controller.installPlainBackButtons()
                controller.schedulePlainBackRefresh()
            }
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if #available(iOS 26.0, *) {
            installPlainBackButtons()
        }
        ThemeUIUtils.styleNavigationButtons(on: navigationBar, tint: navigationBar.tintColor)
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === interactivePopGestureRecognizer {
            // UIKit's own delegate refuses this gesture once a custom left item exists.
            // A transition already in flight should not start a second pop.
            return viewControllers.count > 1 && transitionCoordinator == nil
        }
        return true
    }

    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        viewController.loadViewIfNeeded()
        ThemeUIUtils.styleContentButtons(in: viewController.view)
    }

    /// The system back button keeps a glass capsule on iOS 26 even when hidesSharedBackground is set.
    /// A plain left item follows the previous screen's title and does not draw that capsule.
    /// Called after the bar tint is assigned. A trait change inside `applyTheme` can
    /// lay this controller out before that assignment, which would leave the chevron
    /// on the previous color.
    @available(iOS 26.0, *)
    func installPlainBackButtons() {
        let controllers = viewControllers
        guard controllers.count > 1 else {
            return
        }
        let tint = navigationBar.tintColor ?? Theme.currentTheme().navigationTintColor(octoPrintColor: navigationBarOctoPrintColor)
        for index in 1..<controllers.count {
            let item = controllers[index].navigationItem
            if item.hidesBackButton {
                if item.leftBarButtonItem?.isPlainBackButton == true {
                    item.leftBarButtonItem = nil
                }
                continue
            }
            let leftItems = item.leftBarButtonItems ?? []
            if leftItems.contains(where: { !$0.isPlainBackButton }) {
                continue
            }
            let title = plainBackTitle(for: controllers[index - 1])
            if let existing = item.leftBarButtonItem, existing.isPlainBackButton {
                updatePlainBack(existing, title: title, tint: tint)
                continue
            }
            let button = Self.plainBackControl(title: title, tint: tint, traits: backButtonTraits)
            button.addTarget(self, action: #selector(plainBackTapped), for: .touchUpInside)
            let created = UIBarButtonItem(customView: button)
            created.isPlainBackButton = true
            created.hidesSharedBackground = true
            created.sharesBackground = false
            created.tintColor = tint
            item.leftBarButtonItem = created
        }
        let topItem = controllers.last?.navigationItem
        let foreignLeft = (topItem?.leftBarButtonItems ?? []).contains { !$0.isPlainBackButton }
        if !foreignLeft {
            interactivePopGestureRecognizer?.isEnabled = true
        }
    }

    @available(iOS 26.0, *)
    private func plainBackTitle(for previous: UIViewController) -> String? {
        let item = previous.navigationItem
        switch item.backButtonDisplayMode {
        case .minimal:
            return nil
        case .generic:
            return NSLocalizedString("Back", comment: "")
        default:
            break
        }
        if let explicit = item.backButtonTitle, !explicit.isEmpty {
            return explicit
        }
        if let supplied = item.backBarButtonItem?.title, !supplied.isEmpty {
            return supplied
        }
        if let title = item.title, !title.isEmpty {
            return title
        }
        return nil
    }

    /// iOS 27 draws a configuration symbol in the label color and applies
    /// `baseForegroundColor` to the title only. The chevron is an original image
    /// in the navigation tint so both parts stay the same color.
    @available(iOS 26.0, *)
    static func backChevronImage(tint: UIColor) -> UIImage? {
        let symbol = UIImage.SymbolConfiguration(textStyle: .body, scale: .large)
        return UIImage(systemName: "chevron.backward", withConfiguration: symbol)?
            .withTintColor(tint, renderingMode: .alwaysOriginal)
    }

    @available(iOS 26.0, *)
    static func plainBackControl(title: String?, tint: UIColor, traits: UITraitCollection) -> UIButton {
        let button = UIButton(type: .system)
        button.configuration = .plain()
        updatePlainBackControl(button, title: title, tint: tint, traits: traits)
        button.sizeToFit()
        var bounds = button.bounds
        bounds.size.height = max(bounds.height, 32)
        bounds.size.width = min(max(bounds.width, 28), 220)
        button.bounds = bounds
        // The navigation bar's traits can lag the button's. Refreshing here uses the
        // style the chevron is actually drawn with, in both appearance directions.
        button.registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (button: UIButton, previous: UITraitCollection) in
            guard previous.userInterfaceStyle != button.traitCollection.userInterfaceStyle else {
                return
            }
            Self.refreshPlainBackForCurrentTraits(button)
        }
        return button
    }

    /// Reuses one control across theme and OS-appearance changes.
    /// The title color is dynamic and redraws itself. The chevron does not:
    /// comparing the dynamic color resolved under the current traits hides a
    /// change, and a static theme color can resolve to the same value as the
    /// dynamic one without tracking appearance the same way.
    @available(iOS 26.0, *)
    static func updatePlainBackControl(_ button: UIButton, title: String?, tint: UIColor, traits: UITraitCollection) {
        let resolved = tint.resolvedColor(with: traits)
        ThemeUIUtils.protectPlainBackControl(button)
        // Remember the color object even when the image is already current. A later
        // appearance change has to resolve this object, not whatever was last baked.
        objc_setAssociatedObject(button, &installedBackTintKey, tint, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        var configuration = button.configuration ?? .plain()
        let titleChanged = configuration.title != title
        let imageStale = configuration.image?.renderingMode != .alwaysOriginal
            || !ThemeUIUtils.sameColor(renderedBackTint(of: button), resolved)
        let foregroundStale = !ThemeUIUtils.colorTracksAppearance(configuration.baseForegroundColor, like: tint)
        if !titleChanged && !imageStale && !foregroundStale {
            return
        }
        configuration.title = title
        configuration.image = backChevronImage(tint: resolved)
        configuration.imagePadding = title == nil ? 0 : 4
        configuration.baseForegroundColor = tint
        configuration.baseBackgroundColor = .clear
        configuration.background = clearBackBackground()
        configuration.contentInsets = .zero
        configuration.titleLineBreakMode = .byTruncatingTail
        configuration.imageColorTransformer = UIConfigurationColorTransformer { _ in resolved }
        button.configuration = configuration
        button.tintColor = tint
        button.accessibilityLabel = title ?? NSLocalizedString("Back", comment: "")
        objc_setAssociatedObject(button, &renderedBackTintKey, resolved, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    /// Traits the chevron is drawn with. The navigation bar can still report the
    /// previous appearance after this controller's style has already changed.
    @available(iOS 26.0, *)
    private var backButtonTraits: UITraitCollection {
        guard let button = viewControllers.last?.navigationItem.leftBarButtonItem?.customView as? UIButton else {
            return traitCollection
        }
        let buttonStyle = button.traitCollection.userInterfaceStyle
        let controllerStyle = traitCollection.userInterfaceStyle
        if buttonStyle != .unspecified && controllerStyle != .unspecified && buttonStyle != controllerStyle {
            return traitCollection
        }
        return buttonStyle == .unspecified ? traitCollection : button.traitCollection
    }

    @available(iOS 26.0, *)
    private func schedulePlainBackRefresh() {
        guard !plainBackRefreshPending else {
            return
        }
        plainBackRefreshPending = true
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            self.plainBackRefreshPending = false
            self.installPlainBackButtons()
        }
    }

    @available(iOS 26.0, *)
    private static func refreshPlainBackForCurrentTraits(_ button: UIButton) {
        guard let tint = objc_getAssociatedObject(button, &installedBackTintKey) as? UIColor else {
            return
        }
        updatePlainBackControl(button, title: button.configuration?.title, tint: tint, traits: button.traitCollection)
    }

    @available(iOS 26.0, *)
    private func updatePlainBack(_ item: UIBarButtonItem, title: String?, tint: UIColor) {
        item.hidesSharedBackground = true
        item.sharesBackground = false
        guard let button = item.customView as? UIButton else {
            return
        }
        let traits = backButtonTraits
        if item.tintColor?.resolvedColor(with: traits) != tint.resolvedColor(with: traits) {
            item.tintColor = tint
        }
        let titleChanged = (button.configuration?.title) != title
        Self.updatePlainBackControl(button, title: title, tint: tint, traits: traits)
        if titleChanged {
            button.sizeToFit()
            var bounds = button.bounds
            bounds.size.height = max(bounds.height, 32)
            bounds.size.width = min(max(bounds.width, 28), 220)
            button.bounds = bounds
        }
    }

    @available(iOS 26.0, *)
    private static func renderedBackTint(of button: UIButton) -> UIColor? {
        objc_getAssociatedObject(button, &renderedBackTintKey) as? UIColor
    }

    @available(iOS 26.0, *)
    private static func clearBackBackground() -> UIBackgroundConfiguration {
        var background = UIBackgroundConfiguration.clear()
        background.backgroundColor = .clear
        background.visualEffect = nil
        background.image = nil
        background.strokeWidth = 0
        background.strokeColor = .clear
        return background
    }

    @objc private func plainBackTapped() {
        popViewController(animated: true)
    }

    // Page content follows the theme. The bar color also follows the printer, so the
    // status bar icons have to be chosen from the bar rather than the interface style.
    override var preferredStatusBarStyle: UIStatusBarStyle {
        ThemeUIUtils.preferredStatusBarStyle(octoPrintColor: navigationBarOctoPrintColor, traits: traitCollection)
    }

    override var childForStatusBarStyle: UIViewController? {
        nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard (UIApplication.shared.delegate as! AppDelegate).isCoreDataReady else {
            coreDataAppearanceDeferred = true
            return
        }
        configureForCoreDataReadyAppearance()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        coreDataAppearanceDeferred = false
        guard (UIApplication.shared.delegate as! AppDelegate).isCoreDataReady else {
            return
        }
        guard coreDataAppearanceSetupActive else {
            return
        }
        // Stop listening to changes to OctoPrint Settings
        octoprintClient.remove(octoPrintSettingsDelegate: self)
        // Stop listening to changes to default printer
        defaultPrinterManager.remove(defaultPrinterManagerDelegate: self)
        coreDataAppearanceSetupActive = false
    }

    @objc private func coreDataDidBecomeReady() {
        guard coreDataAppearanceDeferred else {
            return
        }
        coreDataAppearanceDeferred = false
        configureForCoreDataReadyAppearance()
    }

    private func configureForCoreDataReadyAppearance() {
        if !coreDataAppearanceSetupActive {
            // Listen to changes to OctoPrint Settings in case the camera orientation has changed
            octoprintClient.octoPrintSettingsDelegates.append(self)
            // Listen to changes to default printer
            defaultPrinterManager.delegates.append(self)
            coreDataAppearanceSetupActive = true
        }

        let printer = printerManager.getDefaultPrinter()
        refreshForPrinterColors(color: printer?.color)
    }
    
    func refreshForPrinterColors(color: String?) {
        navigationBarOctoPrintColor = color
        ThemeUIUtils.applyTheme(navigationController: self, octoPrintColor: color)
        setNeedsStatusBarAppearanceUpdate()
    }

    // MARK: - OctoPrintSettingsDelegate
    
    func octoPrintColorChanged(color: String) {
        DispatchQueue.main.async {
            self.refreshForPrinterColors(color: color)
        }
    }
    
    // MARK: - DefaultPrinterManagerDelegate
    
    func defaultPrinterChanged() {
        DispatchQueue.main.async {
            let printer = self.printerManager.getDefaultPrinter()
            self.refreshForPrinterColors(color: printer?.color)
        }
    }

    // UITabBarController asks the selected navigation controller, not its top VC.
    override var shouldAutorotate: Bool {
        topViewController?.shouldAutorotate ?? true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        topViewController?.supportedInterfaceOrientations ?? super.supportedInterfaceOrientations
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        topViewController?.preferredInterfaceOrientationForPresentation ?? super.preferredInterfaceOrientationForPresentation
    }
}
