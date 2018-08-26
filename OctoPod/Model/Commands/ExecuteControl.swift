import Foundation

protocol ExecuteControl: CustomControl {
    
    func input() -> Array<ControlInput>?
    
    func confirm() -> String?
    
    func executePayload() -> NSDictionary
}
