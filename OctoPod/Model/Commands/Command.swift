import Foundation

class Command: ExecuteControl {
    
    private var _name: String
    private var _input: Array<ControlInput>?
    private var _confirm: String?

    var command: String?
    var commands: Array<String>?

    init(name: String, input: Array<ControlInput>?, confirm: String?) {
        self._name = name
        self._input = input
        self._confirm = confirm
    }
    
    // MARK: - CustomControl

    func name() -> String {
        return _name
    }
    
    // MARK: - ExecuteControl
    
    func input() -> Array<ControlInput>? {
        return _input
    }

    func confirm() -> String? {
        return _confirm
    }

    func executePayload() -> NSDictionary {
        let result = NSMutableDictionary()
        if let commandsArray = commands {
            result["commands"] = commandsArray
        } else if let singleCommand = command {
            result["commands"] = [singleCommand]
        }

        var paramsDict: NSMutableDictionary?
        if let input = _input {
            paramsDict = NSMutableDictionary()
            for controlInput in input {
                let entry: (key: String, value: Any) = controlInput.executePayload()
                paramsDict?[entry.key] = entry.value
            }
            result["parameters"] = paramsDict!
        }
        return result
    }
}
