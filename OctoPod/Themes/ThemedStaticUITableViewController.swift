import UIKit
import ObjectiveC

private var dynamicTypePreparedKey: UInt8 = 0
private var dynamicTypeGuideKey: UInt8 = 0

class ThemedStaticUITableViewController: ThemedUITableViewController {

    override func staticCells() -> Bool {
        return true
    }

    /// Settings screens opt in. Other static tables keep their storyboard row heights.
    func usesDynamicTypeRows() -> Bool {
        return false
    }

    /// Return false for a row that must keep a caller-supplied height, such as the
    /// Apple Watch settings row hidden on iPad.
    func allowsDynamicTypeRow(at indexPath: IndexPath) -> Bool {
        return true
    }

    /// True while a row is being measured, so heightForRow does not re-enter.
    private var isMeasuringDynamicRow = false

    override func viewDidLoad() {
        super.viewDidLoad()
        guard usesDynamicTypeRows() else {
            // heightForHeaderInSection now exists for every static table. On a
            // plain table that has no header, that makes UIKit add
            // sectionHeaderTopPadding above the first row. Those screens had
            // no header before the delegate method existed.
            if tableView.style == .plain {
                tableView.sectionHeaderTopPadding = 0
            }
            return
        }
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.estimatedSectionHeaderHeight = 36
        tableView.sectionFooterHeight = UITableView.automaticDimension
        tableView.estimatedSectionFooterHeight = 28
        // Siri, Prompts, and Support were authored with scrolling off. Grown rows
        // have to be able to move onto the screen.
        tableView.isScrollEnabled = true
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard usesDynamicTypeRows() else { return }
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            tableView.reloadData()
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        if usesDynamicTypeRows(), allowsDynamicTypeRow(at: indexPath) {
            SettingsDynamicTypeLayout.prepare(cell)
            SettingsDynamicTypeLayout.applyTableWidth(tableView.bounds.width, to: cell)
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        super.tableView(tableView, willDisplay: cell, forRowAt: indexPath)
        if usesDynamicTypeRows() {
            SettingsDynamicTypeLayout.updateWrappingWidths(in: cell)
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard usesDynamicTypeRows(), allowsDynamicTypeRow(at: indexPath), !isMeasuringDynamicRow else {
            if usesDynamicTypeRows(), allowsDynamicTypeRow(at: indexPath) {
                return UITableView.automaticDimension
            }
            return super.tableView(tableView, heightForRowAt: indexPath)
        }
        guard tableView.bounds.width > 1 else { return UITableView.automaticDimension }
        // Measure the static cell at the real label width. automaticDimension kept the
        // row tall from an earlier narrow width, then the label shrank to one line and
        // clipped the wrapped remainder.
        isMeasuringDynamicRow = true
        let cell = self.tableView(tableView, cellForRowAt: indexPath)
        let height = SettingsDynamicTypeLayout.fittedHeight(of: cell, width: tableView.bounds.width)
        isMeasuringDynamicRow = false
        return height
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        super.tableView(tableView, willDisplayHeaderView: view, forSection: section)
        guard usesDynamicTypeRows(), let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.numberOfLines = 0
        header.textLabel?.lineBreakMode = .byWordWrapping
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        super.tableView(tableView, willDisplayFooterView: view, forSection: section)
        guard usesDynamicTypeRows(), let footer = view as? UITableViewHeaderFooterView else { return }
        footer.textLabel?.numberOfLines = 0
        footer.textLabel?.lineBreakMode = .byWordWrapping
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // UITableViewController does not implement this optional method. Calling
        // super crashes every static table, including ones that do not opt in.
        guard usesDynamicTypeRows() else {
            let title = super.tableView(tableView, titleForHeaderInSection: section)
            // An empty plain section collapses. Returning the storyboard height
            // (File Upload is 20) creates a header, and with the default top
            // padding the first row starts about 42pt lower than it does when
            // this delegate method is absent.
            if tableView.style == .plain, title?.isEmpty != false {
                return 0
            }
            return inheritedSectionHeight(tableView.sectionHeaderHeight)
        }
        let title = super.tableView(tableView, titleForHeaderInSection: section)
        return SettingsDynamicTypeLayout.height(for: title, width: tableView.bounds.width, style: .footnote)
            ?? fixedSectionHeight(tableView.sectionHeaderHeight, fallback: 18)
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        guard usesDynamicTypeRows() else {
            return inheritedSectionHeight(tableView.sectionFooterHeight)
        }
        let title = self.tableView(tableView, titleForFooterInSection: section)
        return SettingsDynamicTypeLayout.height(for: title, width: tableView.bounds.width, style: .footnote)
            ?? fixedSectionHeight(tableView.sectionFooterHeight, fallback: 18)
    }

    /// Non-settings tables keep the storyboard section height, including a
    /// configured 1-point footer that suppresses the grouped footer gap.
    /// automaticDimension (-1) is not a fixed height, so those tables stay on
    /// the system value.
    private func inheritedSectionHeight(_ value: CGFloat) -> CGFloat {
        if value >= 0 && value < 1000 {
            return value
        }
        return UITableView.automaticDimension
    }

    /// Opted-in tables replace the storyboard height with automaticDimension, which
    /// is not a usable delegate return value for an empty title.
    private func fixedSectionHeight(_ value: CGFloat, fallback: CGFloat) -> CGFloat {
        if value > 1 && value < 1000 {
            return value
        }
        return fallback
    }
}

/// Makes storyboard settings rows follow Dynamic Type. Labels and button titles
/// wrap, and the row grows to the text instead of the fixed 44pt storyboard height.
enum SettingsDynamicTypeLayout {
    private static let verticalPadding: CGFloat = 12

    static func prepare(_ cell: UITableViewCell) {
        if objc_getAssociatedObject(cell, &dynamicTypePreparedKey) != nil {
            return
        }
        objc_setAssociatedObject(cell, &dynamicTypePreparedKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        let content = cell.contentView
        let labels = content.subviews.compactMap { $0 as? UILabel }
        let buttons = content.subviews.compactMap { $0 as? UIButton }.filter { buttonHasTitle($0) }
        let switches = content.subviews.compactMap { $0 as? UISwitch }
        let images = content.subviews.compactMap { $0 as? UIImageView }

        for label in labels {
            configureWrappingLabel(label)
        }
        for button in buttons {
            button.titleLabel?.numberOfLines = 0
            button.titleLabel?.lineBreakMode = .byWordWrapping
            button.titleLabel?.textAlignment = .center
            button.titleLabel?.adjustsFontSizeToFitWidth = false
            button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.contentHorizontalAlignment = .center
            button.contentVerticalAlignment = .center
        }
        for toggle in switches {
            toggle.setContentCompressionResistancePriority(.required, for: .horizontal)
            toggle.setContentHuggingPriority(.required, for: .horizontal)
            toggle.setContentCompressionResistancePriority(.required, for: .vertical)
        }
        for image in images {
            image.setContentHuggingPriority(.required, for: .vertical)
            image.setContentCompressionResistancePriority(.required, for: .vertical)
            image.setContentCompressionResistancePriority(.required, for: .horizontal)
        }

        if labels.isEmpty, let button = buttons.first {
            installSizingLabel(matching: button, in: content, on: cell)
        } else if let label = labels.first {
            deactivatePositionConstraints(in: content, of: [label] + switches, includingCenterX: false)
            // Fill the row. A greater-than-or-equal bottom lets the label collapse to one
            // line after the wrapping width changes, which clips the next line.
            label.setContentHuggingPriority(.defaultLow, for: .vertical)
            let top = label.topAnchor.constraint(equalTo: content.topAnchor, constant: verticalPadding)
            let bottom = content.bottomAnchor.constraint(equalTo: label.bottomAnchor, constant: verticalPadding)
            let minimum = content.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
            NSLayoutConstraint.activate([top, bottom, minimum])
            if !hasHorizontalConstraint(label, in: content) {
                NSLayoutConstraint.activate([
                    label.leadingAnchor.constraint(equalTo: content.layoutMarginsGuide.leadingAnchor),
                    label.trailingAnchor.constraint(equalTo: content.layoutMarginsGuide.trailingAnchor)
                ])
            }
        } else {
            // Image-only rows, such as the Support social logos, keep a normal row height.
            let minimum = content.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
            let preferred = content.heightAnchor.constraint(equalToConstant: 44)
            preferred.priority = .defaultLow
            NSLayoutConstraint.activate([minimum, preferred])
        }

        for toggle in switches {
            toggle.centerYAnchor.constraint(equalTo: content.centerYAnchor).isActive = true
        }
    }

    /// Gives wrapping labels a width before the table measures the row. Calling
    /// beginUpdates from viewDidLayoutSubviews loops when the update changes the width.
    static func applyTableWidth(_ tableWidth: CGFloat, to cell: UITableViewCell) {
        guard tableWidth > 1 else { return }
        applyResolvedWidths(in: cell, fallbackWidth: tableWidth)
    }

    /// Height of a settings row at `width`, using the label's laid-out width so a
    /// hyphenated word keeps every line inside the cell.
    static func fittedHeight(of cell: UITableViewCell, width: CGFloat) -> CGFloat {
        guard width > 1 else { return 60 }
        prepare(cell)
        let savedBounds = cell.bounds
        // Lay out the cell, not only its content view, so the disclosure accessory
        // narrows the label the same way it does on screen.
        cell.bounds = CGRect(x: 0, y: 0, width: width, height: max(savedBounds.height, 44))
        cell.setNeedsLayout()
        cell.layoutIfNeeded()
        applyResolvedWidths(in: cell, fallbackWidth: width)

        var height: CGFloat = 44
        let labels = cell.contentView.subviews.compactMap { $0 as? UILabel }
        for label in labels {
            height = max(height, textBlockHeight(label.text ?? "", width: label.preferredMaxLayoutWidth, font: label.font))
        }
        if let guide = objc_getAssociatedObject(cell, &dynamicTypeGuideKey) as? UILabel {
            height = max(height, textBlockHeight(guide.text ?? "", width: guide.preferredMaxLayoutWidth, font: guide.font))
        }
        cell.bounds = savedBounds
        return height
    }

    /// Height of wrapped text plus the row's vertical padding. A single word that
    /// is wider than the label is given a second line, because UILabel hyphenates
    /// it while a plain bounding rect stays on one line.
    private static func textBlockHeight(_ text: String, width: CGFloat, font: UIFont?) -> CGFloat {
        let font = font ?? UIFont.preferredFont(forTextStyle: .body)
        let textWidth = max(width, 40)
        guard !text.isEmpty else { return 44 }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.hyphenationFactor = 1
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .paragraphStyle: paragraph],
            context: nil)
        let singleLine = (text as NSString).size(withAttributes: [.font: font]).width
        var textHeight = ceil(rect.height)
        if singleLine > textWidth - 1 {
            textHeight = max(textHeight, ceil(font.lineHeight * 2))
        }
        return max(44, textHeight + verticalPadding * 2)
    }

    private static func applyResolvedWidths(in cell: UITableViewCell, fallbackWidth: CGFloat) {
        for label in cell.contentView.subviews.compactMap({ $0 as? UILabel }) {
            let resolved = label.bounds.width > 1 ? label.bounds.width : fallbackWidth - (label.textAlignment == .center ? 48 : 120)
            label.preferredMaxLayoutWidth = max(resolved, 40)
        }
        if let guide = objc_getAssociatedObject(cell, &dynamicTypeGuideKey) as? UILabel {
            let resolved = guide.bounds.width > 1 ? guide.bounds.width : fallbackWidth - 36
            guide.preferredMaxLayoutWidth = max(resolved, 40)
        }
    }

    static func updateWrappingWidths(in cell: UITableViewCell) {
        for label in cell.contentView.subviews.compactMap({ $0 as? UILabel }) where label.bounds.width > 1 {
            label.preferredMaxLayoutWidth = label.bounds.width
        }
        for button in cell.contentView.subviews.compactMap({ $0 as? UIButton }) where button.bounds.width > 1 {
            button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.titleLabel?.numberOfLines = 0
            button.titleLabel?.lineBreakMode = .byWordWrapping
            button.titleLabel?.preferredMaxLayoutWidth = button.bounds.width
        }
        if let guide = objc_getAssociatedObject(cell, &dynamicTypeGuideKey) as? UILabel, guide.bounds.width > 1 {
            guide.preferredMaxLayoutWidth = guide.bounds.width
        }
    }

    /// Height for a grouped header or footer. Nil when the title is empty or the
    /// table has not received a width yet, so the caller can keep the storyboard height.
    static func height(for title: String?, width: CGFloat, style: UIFont.TextStyle) -> CGFloat? {
        guard let title, !title.isEmpty, width > 1 else { return nil }
        // Recent iOS draws grouped headers near the body size at accessibility
        // sizes. Measuring with the larger of the requested style and body keeps
        // that title inside the header instead of the old fixed 18pt height.
        let requested = UIFont.preferredFont(forTextStyle: style)
        let body = UIFont.preferredFont(forTextStyle: .body)
        let font = body.lineHeight > requested.lineHeight ? body : requested
        let textWidth = max(width - 48, 40)
        let rect = (title as NSString).boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil)
        let padding = max(28, font.lineHeight * 0.45)
        return ceil(rect.height) + padding
    }

    private static func configureWrappingLabel(_ label: UILabel) {
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.lineBreakStrategy = []
        label.adjustsFontSizeToFitWidth = false
        label.minimumScaleFactor = 1
        label.adjustsFontForContentSizeCategory = true
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .vertical)
    }

    private static func buttonHasTitle(_ button: UIButton) -> Bool {
        let title = button.title(for: .normal) ?? button.currentTitle ?? ""
        return !title.isEmpty
    }

    /// UIButton's intrinsic height stays one line. A hidden label with the same
    /// title and font gives the cell a height that fits the wrapped text, and the
    /// button is stretched to that label so the title is not clipped.
    private static func installSizingLabel(matching button: UIButton, in content: UIView, on cell: UITableViewCell) {
        let guide = UILabel()
        guide.translatesAutoresizingMaskIntoConstraints = false
        guide.text = button.title(for: .normal) ?? button.currentTitle
        guide.font = UIFont.preferredFont(forTextStyle: .body)
        guide.adjustsFontForContentSizeCategory = true
        guide.numberOfLines = 0
        guide.lineBreakMode = .byWordWrapping
        guide.textAlignment = .center
        guide.alpha = 0
        guide.isAccessibilityElement = false
        content.addSubview(guide)
        objc_setAssociatedObject(cell, &dynamicTypeGuideKey, guide, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        let fillsWidth = hasEdgePin(button, in: content)
        deactivatePositionConstraints(in: content, of: [button], includingCenterX: !fillsWidth)

        var pins = [
            guide.topAnchor.constraint(equalTo: content.topAnchor, constant: verticalPadding),
            content.bottomAnchor.constraint(greaterThanOrEqualTo: guide.bottomAnchor, constant: verticalPadding),
            content.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            button.topAnchor.constraint(equalTo: guide.topAnchor),
            button.bottomAnchor.constraint(equalTo: guide.bottomAnchor)
        ]
        if fillsWidth {
            pins.append(guide.leadingAnchor.constraint(equalTo: button.leadingAnchor))
            pins.append(guide.trailingAnchor.constraint(equalTo: button.trailingAnchor))
        } else {
            pins.append(guide.leadingAnchor.constraint(equalTo: content.layoutMarginsGuide.leadingAnchor))
            pins.append(guide.trailingAnchor.constraint(equalTo: content.layoutMarginsGuide.trailingAnchor))
            pins.append(button.leadingAnchor.constraint(equalTo: guide.leadingAnchor))
            pins.append(button.trailingAnchor.constraint(equalTo: guide.trailingAnchor))
        }
        NSLayoutConstraint.activate(pins)
    }

    private static func deactivatePositionConstraints(in content: UIView, of views: [UIView], includingCenterX: Bool) {
        var attributes: Set<NSLayoutConstraint.Attribute> = [.top, .bottom, .centerY]
        if includingCenterX {
            attributes.insert(.centerX)
        }
        for constraint in content.constraints {
            let first = constraint.firstItem as? UIView
            let second = constraint.secondItem as? UIView
            let involvesTarget = views.contains { $0 === first || $0 === second }
            guard involvesTarget else { continue }
            if attributes.contains(constraint.firstAttribute) || attributes.contains(constraint.secondAttribute) {
                constraint.isActive = false
            }
        }
    }

    private static func hasHorizontalConstraint(_ view: UIView, in content: UIView) -> Bool {
        let horizontal: Set<NSLayoutConstraint.Attribute> = [.leading, .trailing, .left, .right, .centerX]
        return content.constraints.contains { constraint in
            let first = constraint.firstItem as? UIView
            let second = constraint.secondItem as? UIView
            let involves = view === first || view === second
            return involves && (horizontal.contains(constraint.firstAttribute) || horizontal.contains(constraint.secondAttribute))
        }
    }

    /// Leading and trailing pins give a button a width. Center-only buttons do not,
    /// so their title cannot wrap until they are pinned to the cell margins.
    private static func hasEdgePin(_ view: UIView, in content: UIView) -> Bool {
        let edges: Set<NSLayoutConstraint.Attribute> = [.leading, .trailing, .left, .right]
        return content.constraints.contains { constraint in
            let first = constraint.firstItem as? UIView
            let second = constraint.secondItem as? UIView
            let involves = view === first || view === second
            return involves && constraint.isActive && (edges.contains(constraint.firstAttribute) || edges.contains(constraint.secondAttribute))
        }
    }
}
