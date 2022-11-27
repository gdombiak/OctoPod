import UIKit

class PrinterViewCell: UICollectionViewCell {

    @IBOutlet weak var printerLabel: UILabel!

    @IBOutlet weak var printedTextLabel: UILabel!
    @IBOutlet weak var printTimeTextLabel: UILabel!
    @IBOutlet weak var printTimeLeftTextLabel: UILabel!
    @IBOutlet weak var printEstimatedCompletionTextLabel: UILabel!
    @IBOutlet weak var printerStatusTextLabel: UILabel!

    @IBOutlet weak var printerStatusLabel: UILabel!
    
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var printTimeLabel: UILabel!
    @IBOutlet weak var printTimeLeftLabel: UILabel!
    @IBOutlet weak var printEstimatedCompletionLabel: UILabel!
    
    @IBOutlet weak var currentHeightTextLabel: UILabel!
    @IBOutlet weak var currentHeightLabel: UILabel!
    @IBOutlet weak var layerTextLabel: UILabel!
    @IBOutlet weak var layerLabel: UILabel!
 
    @IBOutlet weak var printerLabelWidthConstraint: NSLayoutConstraint!

    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        layoutAttributes.bounds.size.height = systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
        return layoutAttributes
    }
}
