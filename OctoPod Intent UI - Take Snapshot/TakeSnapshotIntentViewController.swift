import IntentsUI

/// After TakeSnapshotIntentHandler executed and fetched an image from the printer, this VC will display fetched image together
/// with the printer name we are watching
class TakeSnapshotIntentViewController: UIViewController, INUIHostedViewControlling {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var printerLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    // MARK: - INUIHostedViewControlling
    
    // Prepare your view controller for the interaction to handle.
    func configureView(for parameters: Set<INParameter>, of interaction: INInteraction, interactiveBehavior: INUIInteractiveBehavior, context: INUIHostedViewContext, completion: @escaping (Bool, Set<INParameter>, CGSize) -> Void) {
        // Do configuration here, including preparing views and calculating a desired size for presentation.
        
        guard let intent = interaction.intent as? TakeSnapshotIntent else {
            completion(false, Set(), .zero)
            return
        }
        guard let response = interaction.intentResponse as? TakeSnapshotIntentResponse else {
            completion(false, Set(), .zero)
            return
        }
        if let printer = intent.printer, let inFile = response.image {
            // Display printer name
            printerLabel.text = printer
            // Display fetched image
            imageView.image = UIImage(data: inFile.data)            
            let imageAspectRatio16_9: Bool = response.imageAspectRatio16_9 == 1
            
            /// Adjust height of Siri results window based on image aspect ratio
            var desiredSize = self.extensionContext!.hostedViewMaximumAllowedSize
            let imageHeight = desiredSize.width * (imageAspectRatio16_9 ? 9/16 : 3/4)
            desiredSize.height = imageHeight + 17 + 4 + 4 // Height of image + height of UILabel + spacing
            
            completion(true, parameters, desiredSize)
        } else {
            completion(false, Set(), .zero)
        }
    }
}
