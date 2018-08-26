import Foundation

class ControlInput {
    
    // Variables can be read but cannot be modified
    public private(set) var name: String  // Name to display for the input field.
    public private(set) var parameter: String // Internal parameter name for the input field, used as a placeholder in command/commands
    public private(set) var defaultValue: AnyObject?
    
    var hasSlider: Bool!
    var slider_min: String?
    var slider_max: String?
    var slider_step: String?
    
    init(name: String, parameter: String, defaultValue: AnyObject?) {
        self.name = name
        self.parameter = parameter
        self.defaultValue = defaultValue
        self.hasSlider = false // Assume false until proven otherwise
    }
}
