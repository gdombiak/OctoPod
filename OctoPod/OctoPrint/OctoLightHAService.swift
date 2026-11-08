import Foundation

/// What one OctoLight attempt concluded. The UI decides images, alerts, and haptics from this.
enum OctoLightHAResult: Equatable {
    /// The plugin reported a boolean light state.
    case updated(Bool)
    /// The plugin reported an explicit null state. The light may not have reported yet.
    case stateUnknown
    /// `message` is safe to show. A confirmed rejection and an unconfirmed outcome use different text.
    case failed(message: String, statusCode: Int)
}

enum OctoLightHAFailure {
    static var rejected: String {
        return NSLocalizedString("Failed to toggle light", comment: "")
    }

    /// The body was not a light document. The command may already have run.
    static var unconfirmedResponse: String {
        return NSLocalizedString("OctoPrint did not return an OctoLight status. Whether the light changed is unknown.", comment: "HTTP 200 body was not an OctoLight state document")
    }

    /// URLSession would have changed the method. The original request may already have been processed.
    static var unconfirmedRedirect: String {
        return NSLocalizedString("The light command was redirected to a different HTTP method. Whether the light changed is unknown. Use the printer's final URL.", comment: "POST redirect changed the HTTP method")
    }
}

/// One connection's change counter and the light operations bound to its HTTP client.
/// Sending through this value must not follow a printer switch that happens later.
struct OctoLightHAConnection {
    /// Identifies the server connection captured with these operations. It is not a plugin API version.
    let connectionChangeCounter: UInt
    private let readState: (OctoLightHAAPI, @escaping (OctoLightHAResponse) -> Void) -> Void
    private let toggle: (OctoLightHAAPI, @escaping (OctoLightHAResponse) -> Void) -> Void
    private let turn: (Bool, OctoLightHAAPI, @escaping (OctoLightHAResponse) -> Void) -> Void

    init(connectionChangeCounter: UInt,
         readState: @escaping (OctoLightHAAPI, @escaping (OctoLightHAResponse) -> Void) -> Void,
         toggle: @escaping (OctoLightHAAPI, @escaping (OctoLightHAResponse) -> Void) -> Void,
         turn: @escaping (Bool, OctoLightHAAPI, @escaping (OctoLightHAResponse) -> Void) -> Void) {
        self.connectionChangeCounter = connectionChangeCounter
        self.readState = readState
        self.toggle = toggle
        self.turn = turn
    }

    func getOctoLightHAState(api: OctoLightHAAPI, callback: @escaping (OctoLightHAResponse) -> Void) {
        readState(api, callback)
    }

    func toggleOctoLightHA(api: OctoLightHAAPI, callback: @escaping (OctoLightHAResponse) -> Void) {
        toggle(api, callback)
    }

    func turnOctoLightHA(on: Bool, api: OctoLightHAAPI, callback: @escaping (OctoLightHAResponse) -> Void) {
        turn(on, api, callback)
    }
}

/// The connection the service is following. A snapshot carries the change counter and the client together.
protocol OctoLightHATransport: AnyObject {
    /// Returns nil when no HTTP client is installed.
    func captureOctoLightConnection() -> OctoLightHAConnection?
}

extension OctoPrintClient: OctoLightHATransport {}

/// Chooses the OctoLight contract for one connection, allows one fallback, and translates the outcome.
/// A method rejection on a control can try the other contract once. The REST client performs that single attempt.
/// Timeouts, redirects, unusable bodies, and plugin refusals are final: the command may already have run, or the plugin refused it.
final class OctoLightHAService {
    private let transport: OctoLightHATransport
    private let lock = NSLock()
    private var rememberedAPI: OctoLightHAAPI?
    private var observedChangeCounter: UInt = 0

    convenience init(client: OctoPrintClient) {
        self.init(transport: client)
    }

    init(transport: OctoLightHATransport) {
        self.transport = transport
    }

    func readState(_ completion: @escaping (OctoLightHAResult) -> Void) {
        perform(.readState, completion: completion)
    }

    func toggle(_ completion: @escaping (OctoLightHAResult) -> Void) {
        perform(.toggle, completion: completion)
    }

    func turn(on: Bool, _ completion: @escaping (OctoLightHAResult) -> Void) {
        perform(.turn(on), completion: completion)
    }

    private func perform(_ operation: Operation, allowFallback: Bool = true, completion: @escaping (OctoLightHAResult) -> Void) {
        guard let connection = transport.captureOctoLightConnection() else { return }
        adoptConnectionChangeCounter(connection.connectionChangeCounter)
        let api = currentAPI()
        dispatch(operation, api: api, on: connection) { response in
            self.finish(operation: operation, api: api, changeCounter: connection.connectionChangeCounter, response: response, allowFallback: allowFallback, completion: completion)
        }
    }

    private func finish(operation: Operation, api: OctoLightHAAPI, changeCounter: UInt, response: OctoLightHAResponse, allowFallback: Bool, completion: @escaping (OctoLightHAResult) -> Void) {
        switch interpret(operation: operation, api: api, changeCounter: changeCounter, response: response, allowFallback: allowFallback) {
        case .stale:
            return
        case .done(let outcome):
            if case .failed(let message, let statusCode) = outcome {
                NSLog("OctoLightHA \(operation.logName) failed. Error: \(message). Http response: \(statusCode)")
            }
            completion(outcome)
        case .retry(let nextAPI):
            // The counter check and the client that sends must be the same snapshot.
            // A printer switch between those two steps would otherwise run the fallback on the new printer.
            guard let connection = transport.captureOctoLightConnection(), connection.connectionChangeCounter == changeCounter else { return }
            NSLog("OctoLightHA \(operation.logName) via \(api) returned 405. Retrying with \(nextAPI).")
            dispatch(operation, api: nextAPI, on: connection) { retryResponse in
                self.finish(operation: operation, api: nextAPI, changeCounter: changeCounter, response: retryResponse, allowFallback: false, completion: completion)
            }
        }
    }

    private func dispatch(_ operation: Operation, api: OctoLightHAAPI, on connection: OctoLightHAConnection, callback: @escaping (OctoLightHAResponse) -> Void) {
        switch operation {
        case .readState:
            connection.getOctoLightHAState(api: api, callback: callback)
        case .toggle:
            connection.toggleOctoLightHA(api: api, callback: callback)
        case .turn(let on):
            connection.turnOctoLightHA(on: on, api: api, callback: callback)
        }
    }

    /// A new counter belongs to a replaced or cleared connection, so the learned contract is no longer trustworthy.
    private func adoptConnectionChangeCounter(_ changeCounter: UInt) {
        lock.lock()
        defer { lock.unlock() }
        if changeCounter != observedChangeCounter {
            observedChangeCounter = changeCounter
            rememberedAPI = nil
        }
    }

    private func currentAPI() -> OctoLightHAAPI {
        lock.lock()
        defer { lock.unlock() }
        return rememberedAPI ?? .commands
    }

    private func interpret(operation: Operation, api: OctoLightHAAPI, changeCounter: UInt, response: OctoLightHAResponse, allowFallback: Bool) -> Step {
        lock.lock()
        defer { lock.unlock() }
        guard let current = transport.captureOctoLightConnection(), current.connectionChangeCounter == changeCounter else {
            return .stale
        }

        switch response {
        case .light(let state, let reportedAPI):
            if let reportedAPI = reportedAPI {
                rememberedAPI = reportedAPI
            }
            switch state {
            case .boolean(let isLightOn):
                return .done(.updated(isLightOn))
            case .explicitNull:
                return .done(.stateUnknown)
            }

        case .methodRejected(let statusCode, let pluginMessage):
            guard operation.changesLight else {
                return .done(.failed(message: pluginMessage ?? OctoLightHAFailure.rejected, statusCode: statusCode))
            }
            if allowFallback {
                let nextAPI: OctoLightHAAPI = api == .commands ? .legacy : .commands
                rememberedAPI = nextAPI
                return .retry(nextAPI)
            }
            // Both contracts were rejected. Forget the guess so the next tap starts from commands again.
            rememberedAPI = nil
            return .done(.failed(message: pluginMessage ?? OctoLightHAFailure.rejected, statusCode: statusCode))

        case .rejected(let statusCode, let pluginMessage):
            if api == .commands && (statusCode == 400 || statusCode == 403) {
                rememberedAPI = .commands
            }
            return .done(.failed(message: pluginMessage ?? OctoLightHAFailure.rejected, statusCode: statusCode))

        case .invalid(let statusCode, let pluginMessage):
            return .done(.failed(message: pluginMessage ?? OctoLightHAFailure.unconfirmedResponse, statusCode: statusCode))

        case .methodChangingRedirect(let statusCode):
            return .done(.failed(message: OctoLightHAFailure.unconfirmedRedirect, statusCode: statusCode))

        case .transport(let message, let statusCode):
            return .done(.failed(message: message, statusCode: statusCode))
        }
    }

    private enum Operation {
        case readState
        case toggle
        case turn(Bool)

        var changesLight: Bool {
            switch self {
            case .readState:
                return false
            case .toggle, .turn:
                return true
            }
        }

        var logName: String {
            switch self {
            case .readState:
                return "getState"
            case .toggle:
                return "toggle"
            case .turn(true):
                return "turnOn"
            case .turn(false):
                return "turnOff"
            }
        }
    }

    private enum Step {
        case done(OctoLightHAResult)
        case retry(OctoLightHAAPI)
        case stale
    }
}
