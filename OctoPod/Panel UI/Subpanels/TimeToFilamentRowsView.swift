import UIKit

/// Vertical list of TimeToFilament rows. An empty list has no height.
///
/// Labels are positioned from measured text. A stack view's intrinsic height
/// collapses a wrapped countdown to zero on iOS 18 when the cell is still the
/// previous height, so the table never learns that the row grew.
final class TimeToFilamentRowsView: UIView {
    private(set) var titleLabels: [UILabel] = []
    private(set) var valueLabels: [UILabel] = []
    private var rowContainers: [UIView] = []
    private var rowIDs: [String] = []
    private var fittingWidth: CGFloat = 0
    private var heightConstraint: NSLayoutConstraint?
    private let rowSpacing: CGFloat = 12
    private let columnSpacing: CGFloat = 8

    var labelColor: UIColor = .label {
        didSet { titleLabels.forEach { $0.textColor = labelColor } }
    }

    var valueColor: UIColor = .secondaryLabel {
        didSet { valueLabels.forEach { $0.textColor = valueColor } }
    }

    var rows: [TimeToFilamentRow] = [] {
        didSet {
            guard rows != oldValue else { return }
            updateRows()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        let height = heightAnchor.constraint(equalToConstant: 0)
        height.priority = .required
        height.isActive = true
        heightConstraint = height
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width > 1 ? bounds.width : fittingWidth
        guard width > 1 else { return }
        fittingWidth = width
        positionRows(width: width)
        let height = requiredHeight(for: width)
        if let heightConstraint, abs(heightConstraint.constant - height) > 0.5 {
            heightConstraint.constant = height
        }
    }

    override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize {
        let width = resolvedWidth(targetSize.width)
        guard width > 1 else { return .zero }
        return CGSize(width: width, height: requiredHeight(for: width))
    }

    override var intrinsicContentSize: CGSize {
        let width = bounds.width > 1 ? bounds.width : fittingWidth
        guard width > 1 else {
            return CGSize(width: UIView.noIntrinsicMetric, height: 0)
        }
        return CGSize(width: UIView.noIntrinsicMetric, height: requiredHeight(for: width))
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory else {
            return
        }
        applyFonts(compatibleWith: traitCollection)
    }

    /// Positions the rows for a width the table is about to use, before the view's bounds catch up.
    func layout(fittingWidth width: CGFloat) {
        guard width > 1 else { return }
        fittingWidth = width
        let height = requiredHeight(for: width)
        if let heightConstraint, abs(heightConstraint.constant - height) > 0.5 {
            heightConstraint.constant = height
        }
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    /// Height of every row at `width`, including the space between rows.
    func requiredHeight(for width: CGFloat) -> CGFloat {
        guard width > 1, !titleLabels.isEmpty else { return 0 }
        var total: CGFloat = 0
        for index in titleLabels.indices {
            if index > 0 {
                total += rowSpacing
            }
            total += rowHeight(title: titleLabels[index], value: valueLabels[index], width: width)
        }
        return ceil(total)
    }

    func applyFonts(compatibleWith traits: UITraitCollection) {
        let font = UIFont.preferredFont(forTextStyle: .body, compatibleWith: traits)
        for label in titleLabels + valueLabels {
            label.font = font
            label.adjustsFontForContentSizeCategory = true
        }
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    /// Keeps a container for each `TimeToFilamentRow.id`. A countdown tick changes the
    /// value, and replacing the container would drop VoiceOver focus on that row.
    private func updateRows() {
        if rows.map(\.id) == rowIDs {
            for (index, row) in rows.enumerated() {
                apply(row, title: titleLabels[index], value: valueLabels[index], container: rowContainers[index])
            }
            refreshLayout()
            return
        }

        var available: [String: Int] = [:]
        for (index, id) in rowIDs.enumerated() where available[id] == nil {
            available[id] = index
        }
        var kept = Set<Int>()
        var nextContainers: [UIView] = []
        var nextTitles: [UILabel] = []
        var nextValues: [UILabel] = []
        var nextIDs: [String] = []
        for row in rows {
            if let index = available[row.id], kept.insert(index).inserted {
                apply(row, title: titleLabels[index], value: valueLabels[index], container: rowContainers[index])
                nextContainers.append(rowContainers[index])
                nextTitles.append(titleLabels[index])
                nextValues.append(valueLabels[index])
                nextIDs.append(row.id)
            } else {
                let created = makeRow(row)
                nextContainers.append(created.container)
                nextTitles.append(created.title)
                nextValues.append(created.value)
                nextIDs.append(row.id)
            }
        }
        for (index, container) in rowContainers.enumerated() where !kept.contains(index) {
            container.removeFromSuperview()
        }
        rowContainers = nextContainers
        titleLabels = nextTitles
        valueLabels = nextValues
        rowIDs = nextIDs
        for (index, container) in rowContainers.enumerated() {
            if index < subviews.count, subviews[index] === container {
                continue
            }
            insertSubview(container, at: index)
        }
        let currentElements = accessibilityElements as? [UIView] ?? []
        let sameElements = currentElements.count == rowContainers.count
            && zip(currentElements, rowContainers).allSatisfy { $0 === $1 }
        if !sameElements {
            accessibilityElements = rowContainers
        }
        applyFonts(compatibleWith: traitCollection)
        refreshLayout()
    }

    private func refreshLayout() {
        if fittingWidth > 1 {
            layout(fittingWidth: fittingWidth)
        } else {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    private func apply(_ row: TimeToFilamentRow, title: UILabel, value: UILabel, container: UIView) {
        title.text = row.label
        value.text = row.value
        container.accessibilityLabel = "\(row.label), \(row.value)"
    }

    private func makeRow(_ row: TimeToFilamentRow) -> (container: UIView, title: UILabel, value: UILabel) {
        let title = makeLabel(text: row.label, color: labelColor, alignment: .natural)
        let value = makeLabel(text: row.value, color: valueColor, alignment: .right)
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = true
        container.autoresizingMask = []
        container.isAccessibilityElement = true
        container.accessibilityLabel = "\(row.label), \(row.value)"
        container.addSubview(title)
        container.addSubview(value)
        addSubview(container)
        return (container, title, value)
    }

    private func makeLabel(text: String, color: UIColor, alignment: NSTextAlignment) -> UILabel {
        let label = UILabel()
        // Frames are set in layoutSubviews. Leaving these in Auto Layout made the
        // engine put both labels at the origin with their intrinsic size.
        label.translatesAutoresizingMaskIntoConstraints = true
        label.autoresizingMask = []
        label.text = text
        label.textColor = color
        label.textAlignment = alignment
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.lineBreakStrategy = []
        label.isAccessibilityElement = false
        return label
    }

    private func positionRows(width: CGFloat) {
        var y: CGFloat = 0
        for index in titleLabels.indices {
            if index > 0 {
                y += rowSpacing
            }
            let title = titleLabels[index]
            let value = valueLabels[index]
            let container = rowContainers[index]
            let height = rowHeight(title: title, value: value, width: width)
            container.frame = CGRect(x: 0, y: y, width: width, height: height)
            if needsVertical(title: title, value: value, width: width) {
                // The countdown sits under the event name. A full-width right alignment
                // puts the clock on the far edge and reads as a second, unrelated row.
                value.textAlignment = .natural
                let titleHeight = textHeight(title, width: width)
                title.frame = CGRect(x: 0, y: 0, width: width, height: titleHeight)
                let valueHeight = textHeight(value, width: width)
                value.frame = CGRect(x: 0, y: titleHeight + columnSpacing, width: width, height: valueHeight)
            } else {
                value.textAlignment = .right
                let titleWidth = singleLineWidth(title)
                let valueWidth = singleLineWidth(value)
                title.frame = CGRect(x: 0, y: 0, width: titleWidth, height: height)
                value.frame = CGRect(x: width - valueWidth, y: 0, width: valueWidth, height: height)
            }
            title.preferredMaxLayoutWidth = title.frame.width
            value.preferredMaxLayoutWidth = value.frame.width
            y += height
        }
    }

    private func rowHeight(title: UILabel, value: UILabel, width: CGFloat) -> CGFloat {
        if needsVertical(title: title, value: value, width: width) {
            return textHeight(title, width: width) + columnSpacing + textHeight(value, width: width)
        }
        return max(textHeight(title, width: singleLineWidth(title)), textHeight(value, width: singleLineWidth(value)))
    }

    private func needsVertical(title: UILabel, value: UILabel, width: CGFloat) -> Bool {
        singleLineWidth(title) + singleLineWidth(value) + columnSpacing > width
    }

    private func textHeight(_ label: UILabel, width: CGFloat) -> CGFloat {
        guard let text = label.text, !text.isEmpty, width > 1, let font = label.font else { return 0 }
        let fallback = ceil((text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil).height)
        let measured = ceil(label.textRect(
            forBounds: CGRect(x: 0, y: 0, width: width, height: .greatestFiniteMagnitude),
            limitedToNumberOfLines: 0).height)
        let line = ceil(font.lineHeight)
        // textRect can return zero or an unbounded height before the label has a width.
        if measured >= line, measured <= fallback + line {
            return measured
        }
        return max(fallback, line)
    }

    private func singleLineWidth(_ label: UILabel) -> CGFloat {
        guard let text = label.text, let font = label.font else { return 0 }
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    private func resolvedWidth(_ proposed: CGFloat) -> CGFloat {
        if proposed > 1, proposed < UIView.noIntrinsicMetric {
            return proposed
        }
        if bounds.width > 1 {
            return bounds.width
        }
        return fittingWidth
    }
}
