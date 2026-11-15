import CoreData
import Foundation

/// One `/api/settings` attempt. The values are captured when that attempt starts.
struct TimeToFilamentSettingsRefresh: Equatable {
    let printerID: NSManagedObjectID
    /// Server the attempt was sent to. Nil leaves the hostname already stored for this printer.
    let hostname: String?
    let connection: UInt
    let refreshID: UInt
}

/// Display definitions for one OctoPrint client. OctoPrint remains the source of truth.
/// Live matches and countdowns stay in `TimeToFilamentPanelState`.
final class TimeToFilamentService {
    private struct Cache {
        var hostname: String?
        var lines: [TimeToFilamentDisplayLine]
    }

    private let lock = NSLock()
    private var cacheByPrinterURL: [String: Cache] = [:]
    private var connectionByPrinterURL: [String: UInt] = [:]
    private var acceptedRefreshByPrinterURL: [String: UInt] = [:]
    /// Connection generation installed on the client now. Disconnect and printer switches advance it.
    private var activeConnection: UInt = 0

    /// Called on the settings callback thread after an attempt has entered apply and before it is accepted.
    var beforeApply: ((TimeToFilamentSettingsRefresh) -> Void)?

    func lines(printerURL: String) -> [TimeToFilamentDisplayLine]? {
        lock.lock()
        defer { lock.unlock() }
        return cacheByPrinterURL[printerURL]?.lines
    }

    /// Lines for a delivery the UI is about to paint. Nil when this printer's connection is no longer active,
    /// including after a disconnect or a switch to another printer. An empty list is current.
    func linesIfCurrent(printerURL: String) -> [TimeToFilamentDisplayLine]? {
        lock.lock()
        defer { lock.unlock() }
        guard let connection = connectionByPrinterURL[printerURL], connection == activeConnection else {
            return nil
        }
        return cacheByPrinterURL[printerURL]?.lines
    }

    /// Connection generation installed now. Settings attempts stamp this when they start.
    func activeConnectionStamp() -> UInt {
        lock.lock()
        defer { lock.unlock() }
        return activeConnection
    }

    /// The client is no longer on `connection`'s predecessor. Cached lines stay where they are.
    func noteActiveConnection(_ connection: UInt) {
        lock.lock()
        activeConnection = connection
        lock.unlock()
    }

    /// The printer object now points at `hostname`. Definitions from another server are dropped.
    /// `notify` runs before the lock is released, and only when listeners should see an empty list.
    /// It must only enqueue. A same-host reconnect records the connection and keeps the lines.
    func noteServer(printerID: NSManagedObjectID, hostname: String, connection: UInt, notify: ([TimeToFilamentDisplayLine]) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        activeConnection = connection
        let printerURL = printerID.uriRepresentation().absoluteString
        connectionByPrinterURL[printerURL] = connection
        guard var existing = cacheByPrinterURL[printerURL], existing.hostname != hostname else {
            return
        }
        existing = Cache(hostname: hostname, lines: [])
        cacheByPrinterURL[printerURL] = existing
        notify([])
    }

    /// Validate, write, then enqueue. `notify` runs before the lock is released, so a newer attempt
    /// cannot be delivered ahead of an attempt that already won, and a loser does not notify at all.
    /// `notify` must only enqueue.
    func apply(lines: [TimeToFilamentDisplayLine], refresh: TimeToFilamentSettingsRefresh, notify: ([TimeToFilamentDisplayLine]) -> Void) {
        beforeApply?(refresh)
        lock.lock()
        defer { lock.unlock() }
        let printerURL = refresh.printerID.uriRepresentation().absoluteString
        if refresh.connection != activeConnection {
            return
        }
        if let current = connectionByPrinterURL[printerURL], refresh.connection != current {
            return
        }
        if let accepted = acceptedRefreshByPrinterURL[printerURL], refresh.refreshID <= accepted {
            return
        }
        var entry = cacheByPrinterURL[printerURL] ?? Cache(hostname: refresh.hostname, lines: lines)
        entry.lines = lines
        if let hostname = refresh.hostname {
            entry.hostname = hostname
        }
        cacheByPrinterURL[printerURL] = entry
        connectionByPrinterURL[printerURL] = refresh.connection
        acceptedRefreshByPrinterURL[printerURL] = refresh.refreshID
        notify(lines)
    }

    /// A delivery already queued on the main queue. Obsolete after a disconnect, a printer switch,
    /// or a newer accept for this printer.
    func deliverIfCurrent(printerURL: String, connection: UInt, refreshID: UInt?, notify: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard connection == activeConnection else { return }
        if let refreshID {
            guard acceptedRefreshByPrinterURL[printerURL] == refreshID else { return }
        }
        notify()
    }
}
