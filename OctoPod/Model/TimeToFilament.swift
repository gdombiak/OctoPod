import Foundation

/// One configured row from TimeToFilament settings, in the plugin's order.
struct TimeToFilamentDisplayLine: Equatable {
    let description: String
    let regex: String
    let enabled: Bool
}

/// One upcoming G-code match from a `current` websocket message.
struct TimeToFilamentMatch: Equatable {
    let regex: String
    /// Print time still left, in seconds, when the printer reaches this line.
    /// Seconds until the event are `printTimeLeft - timeLeftAtMatch`.
    let timeLeftAtMatch: Double
}

/// A row ready for the printer panel or the Apple TV detail screen.
struct TimeToFilamentRow: Equatable, Identifiable {
    let id: String
    let label: String
    let value: String
}

enum TimeToFilamentLines {
    /// Lines from `/api/settings` `plugins`. An absent plugin or an unreadable list is no lines.
    static func parse(plugins: NSDictionary) -> [TimeToFilamentDisplayLine] {
        guard let plugin = plugins[Plugins.TIME_TO_FILAMENT] as? NSDictionary,
              let rawLines = plugin["displayLines"] as? NSArray else {
            return []
        }
        var lines: [TimeToFilamentDisplayLine] = []
        for case let raw as NSDictionary in rawLines {
            guard let description = raw["description"] as? String,
                  let regex = raw["regex"] as? String,
                  let enabled = raw["enabled"] as? Bool else {
                continue
            }
            lines.append(TimeToFilamentDisplayLine(description: description, regex: regex, enabled: enabled))
        }
        return lines
    }
}

enum TimeToFilamentMatches {
    /// Matches inside `current.plugins`. An absent TimeToFilament entry is no matches.
    static func parse(plugins: NSDictionary) -> [TimeToFilamentMatch] {
        guard let plugin = plugins[Plugins.TIME_TO_FILAMENT] as? NSDictionary else {
            return []
        }
        var matches: [TimeToFilamentMatch] = []
        for case let regex as String in plugin.allKeys {
            guard let body = plugin[regex] as? NSDictionary, let timeLeft = seconds(body["timeLeft"]) else {
                continue
            }
            matches.append(TimeToFilamentMatch(regex: regex, timeLeftAtMatch: timeLeft))
        }
        return matches
    }

    private static func seconds(_ value: Any?) -> Double? {
        if let value = value as? Double {
            return finite(value)
        }
        if let value = value as? Int {
            return finite(Double(value))
        }
        if let value = value as? NSNumber {
            return finite(value.doubleValue)
        }
        return nil
    }

    private static func finite(_ value: Double) -> Double? {
        value.isFinite ? value : nil
    }
}

/// Joins saved display lines with the latest printer snapshot.
struct TimeToFilamentSnapshot {
    private(set) var lines: [TimeToFilamentDisplayLine] = []
    private(set) var matches: [TimeToFilamentMatch] = []
    private(set) var printTimeLeft: Int?
    private(set) var printing = false
    private(set) var paused = false

    mutating func clear() {
        self = TimeToFilamentSnapshot()
    }

    mutating func apply(lines: [TimeToFilamentDisplayLine]) {
        self.lines = lines
    }

    /// Copies only the fields this event carried. A partial event leaves matches as they were,
    /// unless it explicitly says the printer is not printing. PrintDone and the other partial events
    /// are not full snapshots, and the previous job's matches must not come back when the next job starts.
    /// A full `current` snapshot always carries matches, using an empty list when OctoPrint omitted `plugins`.
    mutating func apply(event: CurrentStateEvent) {
        if let printing = event.printing {
            self.printing = printing
            if !printing && event.paused == nil {
                paused = false
            }
        }
        if let paused = event.paused {
            self.paused = paused
        }
        if let seconds = event.progressPrintTimeLeft {
            printTimeLeft = seconds
        } else if event.progressPrintTime != nil {
            printTimeLeft = nil
        }
        if let matches = event.timeToFilamentMatches {
            self.matches = matches
        } else if event.printing == false {
            matches = []
        }
    }

    func rows(includesApproximationPhrase: Bool) -> [TimeToFilamentRow] {
        guard printing || paused, let printTimeLeft = printTimeLeft else {
            return []
        }
        var timeLeftByRegex: [String: Double] = [:]
        for match in matches {
            if timeLeftByRegex[match.regex] == nil {
                timeLeftByRegex[match.regex] = match.timeLeftAtMatch
            }
        }
        var rows: [TimeToFilamentRow] = []
        for (index, line) in lines.enumerated() where line.enabled {
            guard let timeLeftAtMatch = timeLeftByRegex[line.regex] else {
                continue
            }
            let delta = (Double(printTimeLeft) - timeLeftAtMatch).rounded()
            // `Int(_:)` traps when the estimate is outside the integer range. Drop that row instead.
            guard var secondsUntil = Int(exactly: delta) else {
                continue
            }
            // OctoPrint's formatDuration shows 00:00:00 for a negative result while the match is still
            // present. printTimeLeft moves in coarse steps, so the pause at M600 is often a few seconds negative.
            if secondsUntil < 0 {
                secondsUntil = 0
            }
            rows.append(TimeToFilamentRow(
                id: "\(index)\u{1f}\(line.regex)",
                label: line.description,
                value: TimeToFilamentFormatting.value(secondsUntil: secondsUntil, includesApproximationPhrase: includesApproximationPhrase)
            ))
        }
        return rows
    }
}

/// Remembers which printer the open panel is showing and ignores the other one's data.
struct TimeToFilamentPanelState {
    private(set) var selectedPrinterURL: String?
    private var snapshot = TimeToFilamentSnapshot()

    mutating func noteSelectedPrinter(_ url: String?) {
        guard url != selectedPrinterURL else {
            return
        }
        selectedPrinterURL = url
        snapshot.clear()
    }

    mutating func clearContents() {
        snapshot.clear()
    }

    mutating func apply(lines: [TimeToFilamentDisplayLine], printerURL: String) {
        guard printerURL == selectedPrinterURL else {
            return
        }
        snapshot.apply(lines: lines)
    }

    /// Applies the lines that are still current for the selected printer.
    /// `currentLines` is nil when the delivery's connection is no longer active, so a queued
    /// callback cannot put the previous server's definitions back.
    mutating func applyDeliveredLines(printerURL: String, selectedPrinterURL: String?, currentLines: [TimeToFilamentDisplayLine]?) {
        noteSelectedPrinter(selectedPrinterURL)
        guard printerURL == self.selectedPrinterURL, let currentLines else {
            return
        }
        apply(lines: currentLines, printerURL: printerURL)
    }

    mutating func apply(event: CurrentStateEvent) {
        guard event.printerURL == selectedPrinterURL else {
            return
        }
        snapshot.apply(event: event)
    }

    func rows(includesApproximationPhrase: Bool) -> [TimeToFilamentRow] {
        snapshot.rows(includesApproximationPhrase: includesApproximationPhrase)
    }
}

enum TimeToFilamentFormatting {
    /// One value. The plugin's `format` field is a JavaScript template, not a clock-or-countdown flag,
    /// so every row stays a countdown. Zero is Now. Under a minute the countdown counts seconds.
    /// An hour or more stays a day, hour, and minute duration.
    static func value(secondsUntil: Int, includesApproximationPhrase: Bool) -> String {
        countdown(secondsUntil: secondsUntil, includesApproximationPhrase: includesApproximationPhrase)
    }

    /// The shared print-time formatter counts minutes only, so 1–59 seconds would read as zero minutes.
    /// Print Time Left keeps that formatter. These rows count seconds until a full minute remains.
    private static func countdown(secondsUntil: Int, includesApproximationPhrase: Bool) -> String {
        if secondsUntil == 0 {
            return NSLocalizedString("Now", comment: "A filament change or pause is happening now")
        }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .brief
        formatter.includesApproximationPhrase = includesApproximationPhrase
        formatter.allowedUnits = secondsUntil < 60 ? [.second] : [.day, .hour, .minute]
        return formatter.string(from: TimeInterval(secondsUntil))
            ?? UIUtils.secondsToTimeLeft(seconds: secondsUntil, includesApproximationPhrase: includesApproximationPhrase, ifZero: NSLocalizedString("Now", comment: "A filament change or pause is happening now"))
    }
}
