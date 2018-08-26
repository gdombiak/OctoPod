import Foundation

class ControlInput {
    
    // Variables can be read but cannot be modified
    public private(set) var name: String  // Name to display for the input field.
    public private(set) var parameter: String // Internal parameter name for the input field, used as a placeholder in command/commands

    var defaultValue: AnyObject?  // This variable seems to be required but it sometimes comes as null. We will try to set some default value whenever possible but not always possible so marking as Optional
    var value: AnyObject? // Value set before executing command. This value will be reset/lost when Custom Controls are reloaded from OctoPrint
    
    var hasSlider: Bool!
    var slider_min: String?
    var slider_max: String?
    var slider_step: String?
    
    init(name: String, parameter: String) {
        self.name = name
        self.parameter = parameter
        self.hasSlider = false // Assume false until proven otherwise
    }
}
