import Foundation

class Script: ExecuteControl {
    private var _name: String
    private var _input: Array<ControlInput>?
    private var _confirm: String?

    // Variable can be read but cannot be modified
    public private(set) var script: String
    
    init(name: String, script: String, input: Array<ControlInput>?, confirm: String?) {
        self._name = name
        self._input = input
        self._confirm = confirm
        self.script = script
    }
    
    // MARK: - CustomControl
    
    func name() -> String {
        return _name
    }
    
    // MARK: = ExecuteControl
    
    func input() -> Array<ControlInput>? {
        return _input
    }
    
    func confirm() -> String? {
        return _confirm
    }
    
    func executePayload() -> NSDictionary {
        let result = NSMutableDictionary()
        result["script"] = script
        
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
