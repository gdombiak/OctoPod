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
    
    func isCommand() -> Bool {
        return false
    }
    
    func isScript() -> Bool {
        return true
    }
}
