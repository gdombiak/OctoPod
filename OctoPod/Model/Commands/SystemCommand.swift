import Foundation

class SystemCommand {
    
    private(set) var name: String
    private(set) var action: String
    private(set) var source: String

    init(name: String, action: String, source: String) {
        self.name = name
        self.action = action
        self.source = source
    }
    
}
