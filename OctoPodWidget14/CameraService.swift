import Foundation
import UIKit

class CameraService: ObservableObject {
    @Published var image: UIImage?
    @Published var imageRatio: CGFloat?
    @Published var errorMessage: String?
    
    private var cameraURL: String!
    private var cameraOrientation: Int!
    private var username: String?
    private var password: String?
    private var headers: String?
    private var preemptiveAuth: Bool
    
    init(cameraURL: String, cameraOrientation: Int, username: String?, password: String?, headers: String?, preemptiveAuth: Bool) {
        self.cameraURL = cameraURL
        self.cameraOrientation = cameraOrientation
        self.username = username
        self.password = password
        self.headers = headers
        self.preemptiveAuth = preemptiveAuth
    }
    
    func renderImage(completion: @escaping () -> ()) {
        if let url = URL(string: cameraURL) {
            let orientation = UIImage.Orientation(rawValue: self.cameraOrientation)!
            let timeoutInterval: TimeInterval = 2 // Timeout fast so widget does not fail to render in case of an error
            CameraUtils.shared.renderImage(cameraURL: url, imageOrientation: orientation, username: username, password: password, headers: headers, preemptive: preemptiveAuth, timeoutInterval: timeoutInterval) { (image: UIImage?, errorMessage: String?) in
                if let image = image {
                    DispatchQueue.main.async {
                        // Notify that we got our first image and we know its ratio
                        self.image = image
                        self.imageRatio = image.size.height / image.size.width
                        // Execute completion block when done
                        completion()
                    }
                } else {
                    DispatchQueue.main.async {
                        self.image = nil
                        // Display error messages
                        self.errorMessage = errorMessage!
                        // Execute completion block when done
                        completion()
                    }
                }
            }
        } else {
            self.image = nil
            // Display error messages
            self.errorMessage = NSLocalizedString("No camera", comment: "No camera was configured")
            // Execute completion block when done
            completion()
        }
    }
}
