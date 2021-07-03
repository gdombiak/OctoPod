import UIKit

class CameraGridViewCell: UICollectionViewCell {

    /// Private variable to handle adding and removing from super view
    private weak var _hostedView: UIView? {
        didSet {
            if let oldValue = oldValue {
                if oldValue.isDescendant(of: self) { //Make sure that hostedView hasn't been added as a subview to a different cell
                    oldValue.removeFromSuperview()
                }
            }

            if let _hostedView = _hostedView {
                _hostedView.frame = contentView.bounds
                contentView.addSubview(_hostedView)
            }
        }
    }

    /// Public lazy variable that properly handles hosted views
    weak var hostedView: UIView? {
        get {
            /// Only return hosted view if the cell has not been reused. This means
            /// that hosted view is stil part of this cell
            guard _hostedView?.isDescendant(of: self) ?? false else {
                _hostedView = nil
                return nil
            }

            return _hostedView
        }
        set {
            _hostedView = newValue
        }
    }
}
