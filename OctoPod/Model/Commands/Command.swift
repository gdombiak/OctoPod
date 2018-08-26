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

    func isCommand() -> Bool {
        return true
    }
    
    func isScript() -> Bool {
        return false
    }
}
