import Foundation

enum PrinterConnectionType: Int16 {
    /// Use Global API Key to connect to OctoPrint
    case apiKey = 0
    /// Register an Application Key for this OctoPod instance to talk to OctoPrint
    case applicationKey = 1
    /// Connect to OctoPrint via OctoEverywhere
    case octoEverywhere = 2
    /// Connect to OctoPrint via The Spaghetti Detective tunneling
    case theSpaghettiDetective = 3
}
