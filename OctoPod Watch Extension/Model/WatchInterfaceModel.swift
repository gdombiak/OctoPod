import Foundation

enum WatchPage: Int, Hashable {
    case printers
    case panel
    case cameras

    /// Panel is the landing page once the watch already has printers. An empty watch opens on Printers.
    static func initial(printerCount: Int) -> WatchPage {
        printerCount > 0 ? .panel : .printers
    }
}

struct WatchPrinterRow: Equatable {
    var name: String
    var isDefault: Bool
}

struct WatchPrinterListState: Equatable {
    var rows: [WatchPrinterRow]
    var showsSyncPrompt: Bool
    var showsRefresh: Bool
}

enum WatchPrinterList {
    static func position(of printer: [String: Any]) -> Int {
        // Position was added after the first watch files were saved, so a missing key sorts as 0.
        guard printer.keys.contains("position") else {
            return 0
        }
        if let value = printer["position"] as? Int16 {
            return Int(value)
        }
        if let value = printer["position"] as? Int {
            return value
        }
        if let number = printer["position"] as? NSNumber {
            return number.intValue
        }
        return 0
    }

    static func name(of printer: [String: Any]) -> String {
        printer["name"] as? String ?? ""
    }

    static func isDefault(_ printer: [String: Any]) -> Bool {
        printer["isDefault"] as? Bool ?? false
    }

    static func sorted(_ printers: [[String: Any]]) -> [[String: Any]] {
        printers.sorted { lhs, rhs in
            let left = position(of: lhs)
            let right = position(of: rhs)
            if left == right {
                return name(of: lhs) < name(of: rhs)
            }
            return left < right
        }
    }

    static func state(for printers: [[String: Any]]) -> WatchPrinterListState {
        let rows = sorted(printers).map { printer in
            WatchPrinterRow(name: name(of: printer), isDefault: isDefault(printer))
        }
        return WatchPrinterListState(rows: rows, showsSyncPrompt: printers.isEmpty, showsRefresh: !printers.isEmpty)
    }
}

struct WatchTempSlot: Equatable {
    var text: String
    var enabled: Bool

    static let placeholder = WatchTempSlot(text: "     ", enabled: false)
}

struct WatchToolRow: Equatable {
    var visible: Bool
    var leading: WatchTempSlot
    var trailing: WatchTempSlot

    static let hidden = WatchToolRow(visible: false, leading: .placeholder, trailing: .placeholder)
}

struct WatchJobButtons: Equatable {
    var showsGroup: Bool
    var showsResume: Bool
    var showsPause: Bool
    var showsCancel: Bool

    static let hidden = WatchJobButtons(showsGroup: false, showsResume: false, showsPause: false, showsCancel: false)
}

struct WatchPanelState: Equatable {
    var showsError: Bool = false
    var errorText: String?
    var stateText: String?
    var completionText: String?
    var timeLeftText: String?
    var etaText: String?
    var bedTempText: String? = "    "
    var tool0Text: String = "     "
    var row1: WatchToolRow = .hidden
    var row2: WatchToolRow = .hidden
    var row3: WatchToolRow = .hidden
    var jobButtons: WatchJobButtons = .hidden
    var showsPalette2: Bool = false
    var palette2LastPing: String?
    var palette2LastVariance: String?

    mutating func clearFields() {
        stateText = nil
        completionText = nil
        timeLeftText = nil
        etaText = nil
        bedTempText = nil
        tool0Text = "     "
        row1.leading.text = "     "
        row1.trailing.text = "     "
        row2.leading.text = "     "
        row2.trailing.text = "     "
        row3.leading.text = "     "
    }

    /// Applies one panel payload. Job buttons for any printer value other than printing, paused, or
    /// operational stay as they were, and tool rows stay as they were when tool 0 is absent.
    mutating func apply(panelInfo: [String: Any], now: Date = Date(), screenWidth: Double = 200, calendar: Calendar = .current) {
        if let error = panelInfo["error"] as? String {
            showsError = true
            errorText = error
            stateText = nil
            completionText = nil
            timeLeftText = nil
            etaText = nil
            bedTempText = "    "
            tool0Text = "     "
            row1.visible = false
            row1.leading.enabled = false
            row1.trailing.enabled = false
            row2.visible = false
            row2.leading.enabled = false
            row2.trailing.enabled = false
            row3.visible = false
            row3.leading.enabled = false
            jobButtons = .hidden
        } else {
            showsError = false
            errorText = nil
            if let state = panelInfo["state"] as? String {
                stateText = state.hasPrefix("Offline (Error:") ? "Offline" : state
            }
            if let completion = panelInfo["completion"] as? Double {
                completionText = "\(String(format: "%.1f", completion))%"
            }
            if let printTimeLeft = panelInfo["printTimeLeft"] as? Int {
                let includeMinutes = WatchTimeFormatting.includeMinutes(screenWidth: screenWidth, seconds: printTimeLeft)
                timeLeftText = WatchTimeFormatting.timeLeft(seconds: printTimeLeft, includeMinutes: includeMinutes, calendar: calendar)
                etaText = WatchTimeFormatting.eta(seconds: printTimeLeft, now: now, calendar: calendar)
            } else if let printTimeLeft = panelInfo["printTimeLeft"] as? String {
                timeLeftText = printTimeLeft
                etaText = nil
            }
            if let bedTemp = panelInfo["bedTemp"] as? Double {
                bedTempText = WatchTimeFormatting.temperature(bedTemp)
            }
            if let tool0Temp = panelInfo["tool0Temp"] as? Double {
                tool0Text = WatchTimeFormatting.temperature(tool0Temp)
                let tool1 = Self.updatedTemp("tool1Temp", in: panelInfo, slot: row1.leading)
                let chamber = Self.updatedTemp("chamberTemp", in: panelInfo, slot: row1.trailing)
                row1.leading = tool1.slot
                row1.trailing = chamber.slot
                row1.visible = tool1.present || chamber.present

                let tool2 = Self.updatedTemp("tool2Temp", in: panelInfo, slot: row2.leading)
                let tool3 = Self.updatedTemp("tool3Temp", in: panelInfo, slot: row2.trailing)
                row2.leading = tool2.slot
                row2.trailing = tool3.slot
                row2.visible = tool2.present || tool3.present

                let tool4 = Self.updatedTemp("tool4Temp", in: panelInfo, slot: row3.leading)
                row3.leading = tool4.slot
                row3.visible = tool4.present
            }
            if let printer = panelInfo["printer"] as? String {
                jobButtons.showsGroup = true
                if printer == "printing" {
                    jobButtons.showsResume = false
                    jobButtons.showsPause = true
                    jobButtons.showsCancel = true
                } else if printer == "paused" {
                    jobButtons.showsResume = true
                    jobButtons.showsPause = false
                    jobButtons.showsCancel = true
                } else {
                    if panelInfo["completion"] == nil {
                        completionText = nil
                    }
                    if panelInfo["printTimeLeft"] == nil {
                        timeLeftText = nil
                        etaText = nil
                    }
                    if printer == "operational" {
                        jobButtons = .hidden
                    }
                }
            } else {
                jobButtons = .hidden
            }
        }

        showsPalette2 = false
        palette2LastPing = nil
        palette2LastVariance = nil
        if let palette2LastPing = panelInfo["palette2LastPing"] as? String,
           let palette2LastVariation = panelInfo["palette2LastVariation"] as? String,
           panelInfo["palette2MaxVariation"] as? String != nil {
            showsPalette2 = true
            self.palette2LastPing = palette2LastPing
            palette2LastVariance = palette2LastVariation
        }
    }

    private static func updatedTemp(_ key: String, in panelInfo: [String: Any], slot: WatchTempSlot) -> (slot: WatchTempSlot, present: Bool) {
        var slot = slot
        if let temp = panelInfo[key] as? Double {
            slot.text = WatchTimeFormatting.temperature(temp)
            slot.enabled = true
            return (slot, true)
        }
        slot.enabled = false
        return (slot, false)
    }
}

enum WatchPanelCache {
    /// Cached panel info is reused when it is younger than 10 seconds. The comparison truncates to whole seconds.
    static func isFresh(lastRefresh: Date, now: Date) -> Bool {
        let diff = Int(now.timeIntervalSince1970 - lastRefresh.timeIntervalSince1970)
        return diff < 10
    }
}

enum WatchScenePhase: Equatable {
    case active, inactive, background
}

/// Decides when the Panel page should refresh. `appear()` covers launch and page selection.
/// A later scene change refreshes only when Panel is selected and the scene returns to `.active`
/// from `.inactive` or `.background`. The phase already in effect at launch is not a second refresh:
/// `onChange` does not emit it, and an explicit initial `.active` has no previous phase.
struct WatchPanelLifecycle {
    private var hasAppeared = false
    private var phase: WatchScenePhase?

    mutating func appear() -> Bool {
        hasAppeared = true
        return true
    }

    mutating func sceneChanged(to newPhase: WatchScenePhase, panelSelected: Bool) -> Bool {
        let previous = phase
        phase = newPhase
        guard newPhase == .active, panelSelected, hasAppeared else {
            return false
        }
        return previous == .inactive || previous == .background
    }
}

/// The phone image the Cameras page is waiting for. `token` is the opaque `cameraId` sent to the iPhone.
/// The phone echoes that string in the file metadata, including an older iPhone that has no request id.
struct WatchCameraPhoneSession: Equatable {
    private(set) var token: String?

    mutating func start(token: String) {
        self.token = token
    }

    mutating func cancel(_ token: String) {
        guard self.token == token else {
            return
        }
        self.token = nil
    }

    /// Image, read-error, refresh, and message-error changes. Acknowledgment order does not matter.
    func matches(_ token: String) -> Bool {
        self.token == token
    }
}

enum WatchCameraFileEvent: Equatable {
    case deliver(token: String, failed: Bool)
    case ignored
}

/// Decides which file transfer reaches the Cameras page. Metadata is read before the file bytes.
enum WatchCameraFile {
    static func event(metadata: [String: Any]?, readFailed: Bool) -> WatchCameraFileEvent {
        // cameraId is an opaque string. Older watches send "0". Newer watches send a request token.
        guard let token = metadata?["cameraId"] as? String, !token.isEmpty else {
            return .ignored
        }
        return .deliver(token: token, failed: readFailed)
    }
}

struct WatchCameraControls: Equatable {
    var index: Int
    var showsPrevious: Bool
    var showsNext: Bool
    var showsImage: Bool
    var cameraId: String
}

enum WatchCameraFallback: Equatable {
    case unsupportedHLS
    case direct
}

/// One direct camera stream. `invalidate()` runs when the user switches cameras or refreshes.
/// Callbacks that captured the previous token must not update the UI or stop the replacement stream.
struct WatchCameraPlayback: Equatable {
    private(set) var token: Int = 0

    mutating func invalidate() {
        token += 1
    }

    func isCurrent(_ captured: Int) -> Bool {
        captured == token
    }
}

enum WatchCameraPage {
    static let empty = WatchCameraControls(index: 0, showsPrevious: false, showsNext: false, showsImage: false, cameraId: "0")

    static func isSelected(_ cameraId: String, selectedCameraId: String) -> Bool {
        cameraId == selectedCameraId
    }

    static func controls(count: Int, index: Int) -> WatchCameraControls {
        let clamped = count < index + 1 ? 0 : index
        return WatchCameraControls(
            index: clamped,
            showsPrevious: clamped > 0,
            showsNext: count - clamped > 1,
            showsImage: count > 0,
            cameraId: "\(clamped)"
        )
    }

    static func fallback(for url: String) -> WatchCameraFallback {
        WatchTimeFormatting.isHLS(url: url) ? .unsupportedHLS : .direct
    }
}

enum WatchTimeFormatting {
    static func includeMinutes(screenWidth: Double, seconds: Int) -> Bool {
        // 38mm watches are 136 points wide and cannot fit minutes once the duration exceeds a day.
        !(seconds > 86400 && screenWidth == 136)
    }

    static func temperature(_ temp: Double) -> String {
        "\(String(format: "%.1f", temp)) C"
    }

    static func timeLeft(seconds: Int, includeMinutes: Bool, calendar: Calendar = .current) -> String {
        if seconds == 0 {
            return ""
        } else if seconds < 0 {
            return NSLocalizedString("Unknown", comment: "ETA is Unknown")
        }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.includesApproximationPhrase = true
        formatter.calendar = calendar
        if includeMinutes {
            formatter.allowedUnits = [.day, .hour, .minute]
        } else {
            formatter.allowedUnits = [.day, .hour]
        }
        return formatter.string(from: TimeInterval(seconds)) ?? ""
    }

    static func eta(seconds: Int, now: Date = Date(), calendar: Calendar = .current) -> String {
        if seconds == 0 {
            return ""
        } else if seconds < 0 {
            return NSLocalizedString("Unknown", comment: "ETA is Unknown")
        }
        guard let etaDate = calendar.date(byAdding: .second, value: seconds, to: now) else {
            NSLog("Failed to create ETA date")
            return ""
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? Locale.current
        formatter.timeZone = calendar.timeZone
        if calendar.isDate(now, inSameDayAs: etaDate) {
            formatter.dateStyle = .none
            formatter.timeStyle = .short
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .short
        }
        return formatter.string(from: etaDate)
    }

    static func isHLS(url: String) -> Bool {
        url.hasSuffix(".m3u8")
    }
}
