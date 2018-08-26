import Foundation

class Container: CustomControl {
    private var path: String
    private var _name: String
    // Variable can be read but cannot be modified
    public private(set) var children: Array<CustomControl>

    init(path: String, name: String, children: Array<CustomControl>) {
        self.path = path
        self._name = name
        self.children = children
    }
    
    // Do a recursive search for the specified file/folder
    func locate(container: Container) -> Container? {
        if path == container.path {
            return self
        } else {
            // Check if any of my children has the specified container
            for case let child as Container in children {
                if let found = child.locate(container: container) {
                    return found
                }
            }
        }
        return nil
    }
    
    // MARK: - CustomControl
    
    func name() -> String {
        return _name
    }
}
