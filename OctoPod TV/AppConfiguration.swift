import Foundation

class AppConfiguration {
    
    // MARK: - SSL Certificate Validation
    
    /// Returns true if SSL Certification validation is disabled. Not recommended
    /// to disable certificates validation but might be necessary for most people
    /// that run OctoPrint with self-signed certificates and still want to use HTTPS
    /// Enabled by default
    func certValidationDisabled() -> Bool {
        return false
    }

}
