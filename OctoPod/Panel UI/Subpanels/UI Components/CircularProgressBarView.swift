import UIKit

class CircularProgressBarView: UIView {
    
    private let shapeLayer  = CAShapeLayer()
    private var circularPath: UIBezierPath?

    override init(frame: CGRect) {
        super.init(frame: frame)
        makeCircle()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        makeCircle()
    }
    
    fileprivate func makeCircle(){
        circularPath = UIBezierPath(arcCenter: .zero, radius: self.bounds.width / 2, startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: true)
        shapeLayer.path = circularPath?.cgPath
        shapeLayer.strokeColor = UIColor.orange.cgColor//UIColor.init(red: 0.0/255.0, green: 0.0/255.0, blue: 0.0/255.0, alpha: 1.0).cgColor
        shapeLayer.lineWidth = 4.0
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineCap = CAShapeLayerLineCap.round
        shapeLayer.strokeEnd = 0
        shapeLayer.position = CGPoint(x: 8, y: 8)
        shapeLayer.transform = CATransform3DRotate(CATransform3DIdentity, -CGFloat.pi / 2, 0, 0, 1)
        self.layer.addSublayer(shapeLayer)

    }
    
    func showProgress(percent: Float){
        shapeLayer.strokeEnd = CGFloat(percent/100)
    }
}
