import XCTest
@testable import OctoPod

final class TimeToFilamentTests: PrinterManagerTestCase {
    private let printerA = "printer-a"
    private let printerB = "printer-b"

    func testSettingsWithoutThePluginProduceNoLines() throws {
        XCTAssertEqual(TimeToFilamentLines.parse(plugins: [:]), [])
        XCTAssertEqual(TimeToFilamentLines.parse(plugins: try jsonObject(#"{"PrintTimeGenius":{}}"#)), [])
    }

    func testSettingsJSONKeepsOrderAndIgnoresTheExternalFlag() throws {
        let plugins = try jsonObject(#"""
        {"TimeToFilament":{"displayLines":[
            {"description":"Time to Next Layer","regex":"^; layer (\\d+)","enabled":true,"enabledExternal":true},
            {"description":"Time of Next Filament Change","regex":"^M600","enabled":false,"enabledExternal":true},
            {"description":"broken","enabled":true},
            {"description":"Time to Next Next Pause","regex":"^M601","enabled":true,"enabledExternal":false}
        ]}}
        """#)

        XCTAssertEqual(TimeToFilamentLines.parse(plugins: plugins), [
            TimeToFilamentDisplayLine(description: "Time to Next Layer", regex: "^; layer (\\d+)", enabled: true),
            TimeToFilamentDisplayLine(description: "Time of Next Filament Change", regex: "^M600", enabled: false),
            TimeToFilamentDisplayLine(description: "Time to Next Next Pause", regex: "^M601", enabled: true)
        ])
    }

    func testSettingsKeepEnabledOrderAndSkipBrokenLines() {
        let plugins: NSDictionary = [
            "TimeToFilament": [
                "displayLines": [
                    ["description": "Time to Next Layer", "regex": "^; layer (\\d+)", "enabled": true],
                    ["description": "missing regex", "enabled": true],
                    ["description": "Time to Next Filament Change", "regex": "^M600", "enabled": true],
                    ["description": "Time of Next Filament Change", "regex": "^M600", "enabled": false],
                    ["description": "Time to Next Next Pause", "regex": "^M601", "enabled": true]
                ]
            ]
        ]

        XCTAssertEqual(TimeToFilamentLines.parse(plugins: plugins), [
            TimeToFilamentDisplayLine(description: "Time to Next Layer", regex: "^; layer (\\d+)", enabled: true),
            TimeToFilamentDisplayLine(description: "Time to Next Filament Change", regex: "^M600", enabled: true),
            TimeToFilamentDisplayLine(description: "Time of Next Filament Change", regex: "^M600", enabled: false),
            TimeToFilamentDisplayLine(description: "Time to Next Next Pause", regex: "^M601", enabled: true)
        ])
    }

    func testCurrentPluginsWithoutThePluginClearMatches() {
        let event = CurrentStateEvent(printerURL: printerA)
        XCTAssertNil(event.timeToFilamentMatches)

        event.parsePlugins(plugins: ["PrintTimeGenius": [:]])
        XCTAssertEqual(event.timeToFilamentMatches, [])
    }

    func testCurrentPluginsReadTimeLeftAtTheMatch() {
        let event = CurrentStateEvent(printerURL: printerA)
        event.parsePlugins(plugins: [
            "TimeToFilament": [
                "^M600": ["timeLeft": 100.4, "groups": []],
                "^M601": ["timeLeft": 50]
            ]
        ])

        XCTAssertEqual(event.timeToFilamentMatches?.sorted { $0.regex < $1.regex }, [
            TimeToFilamentMatch(regex: "^M600", timeLeftAtMatch: 100.4),
            TimeToFilamentMatch(regex: "^M601", timeLeftAtMatch: 50)
        ])
    }

    func testRowsUsePluginLabelsCountdownAndClock() {
        let snapshot = printingSnapshot(printTimeLeft: 3700, matches: [
            TimeToFilamentMatch(regex: "^; layer (\\d+)", timeLeftAtMatch: 3400.4),
            TimeToFilamentMatch(regex: "^M600", timeLeftAtMatch: 100.4),
            TimeToFilamentMatch(regex: "^M601", timeLeftAtMatch: 50)
        ])

        let rows = snapshot.rows(includesApproximationPhrase: true)
        XCTAssertEqual(rows.map(\.label), [
            "Time to Next Layer",
            "Time to Next Filament Change",
            "Time to Next Next Pause"
        ])
        XCTAssertEqual(rows.map(\.value), [
            expectedValue(secondsUntil: 300, approximation: true),
            expectedValue(secondsUntil: 3600, approximation: true),
            expectedValue(secondsUntil: 3650, approximation: true)
        ])
        XCTAssertEqual(snapshot.rows(includesApproximationPhrase: false).map(\.value), [
            expectedValue(secondsUntil: 300, approximation: false),
            expectedValue(secondsUntil: 3600, approximation: false),
            expectedValue(secondsUntil: 3650, approximation: false)
        ])
    }

    func testSharedRegexShowsBothEnabledLines() {
        let snapshot = printingSnapshot(printTimeLeft: 500, matches: [
            TimeToFilamentMatch(regex: "^M600", timeLeftAtMatch: 100)
        ], lines: [
            TimeToFilamentDisplayLine(description: "Time to Next Filament Change", regex: "^M600", enabled: true),
            TimeToFilamentDisplayLine(description: "Time of Next Filament Change", regex: "^M600", enabled: true)
        ])

        let rows = snapshot.rows(includesApproximationPhrase: false)
        XCTAssertEqual(rows.map(\.label), [
            "Time to Next Filament Change",
            "Time of Next Filament Change"
        ])
        XCTAssertEqual(Set(rows.map(\.id)).count, rows.count)
    }

    func testRowsStayHiddenUntilTheJobAndEstimateAreKnown() {
        var snapshot = TimeToFilamentSnapshot()
        snapshot.apply(lines: defaultLines())
        snapshot.apply(event: stateEvent(printer: printerA, printing: false, paused: false, printTimeLeft: 500, matches: [TimeToFilamentMatch(regex: "^M600", timeLeftAtMatch: 100)]))
        XCTAssertTrue(snapshot.rows(includesApproximationPhrase: true).isEmpty)

        snapshot.apply(event: stateEvent(printer: printerA, printing: true, paused: false, printTimeLeft: nil, printTime: 10, matches: [TimeToFilamentMatch(regex: "^M600", timeLeftAtMatch: 100)]))
        XCTAssertTrue(snapshot.rows(includesApproximationPhrase: true).isEmpty)

        snapshot.apply(event: stateEvent(printer: printerA, printing: true, paused: false, printTimeLeft: 50, matches: [TimeToFilamentMatch(regex: "^M600", timeLeftAtMatch: 100)]))
        XCTAssertEqual(snapshot.rows(includesApproximationPhrase: true).map(\.value), ["Now"])

        snapshot.apply(event: stateEvent(printer: printerA, printing: false, paused: true, printTimeLeft: 500, matches: [TimeToFilamentMatch(regex: "^M600", timeLeftAtMatch: 100)]))
        XCTAssertEqual(snapshot.rows(includesApproximationPhrase: false).map(\.label), ["Time to Next Filament Change"])
    }

    func testZeroSecondsReadsNowAndAPartialEventKeepsMatches() {
        var snapshot = printingSnapshot(printTimeLeft: 100, matches: [
            TimeToFilamentMatch(regex: "^M600", timeLeftAtMatch: 100)
        ])
        XCTAssertEqual(snapshot.rows(includesApproximationPhrase: true).map(\.value), ["Now"])

        snapshot = printingSnapshot(printTimeLeft: 1000, matches: [
            TimeToFilamentMatch(regex: "^; layer (\\d+)", timeLeftAtMatch: 200),
            TimeToFilamentMatch(regex: "^M600", timeLeftAtMatch: 100),
            TimeToFilamentMatch(regex: "^M601", timeLeftAtMatch: 50)
        ])
        let partial = CurrentStateEvent(printerURL: printerA)
        partial.printing = true
        partial.progressPrintTimeLeft = 400
        snapshot.apply(event: partial)
        XCTAssertNil(partial.timeToFilamentMatches)
        XCTAssertEqual(snapshot.rows(includesApproximationPhrase: false).map(\.label), [
            "Time to Next Layer",
            "Time to Next Filament Change",
            "Time to Next Next Pause"
        ])
        XCTAssertEqual(snapshot.rows(includesApproximationPhrase: false).map(\.value), [
            expectedValue(secondsUntil: 200, approximation: false),
            expectedValue(secondsUntil: 300, approximation: false),
            expectedValue(secondsUntil: 350, approximation: false)
        ])
    }

    func testANegativeCountdownWhileTheMatchRemainsReadsNow() {
        let behind = printingSnapshot(printTimeLeft: 100, matches: [
            TimeToFilamentMatch(regex: "^M600", timeLeftAtMatch: 100.6)
        ])
        XCTAssertEqual(behind.rows(includesApproximationPhrase: true).map(\.value), ["Now"])

        let now = printingSnapshot(printTimeLeft: 100, matches: [
            TimeToFilamentMatch(regex: "^M600", timeLeftAtMatch: 100.4)
        ])
        XCTAssertEqual(now.rows(includesApproximationPhrase: true).map(\.value), ["Now"])

        // Second M600 on the virtual printer: printTimeLeft stepped to 900 while ^M600 was still 913.8.
        var paused = printingSnapshot(printTimeLeft: 900, matches: [
            TimeToFilamentMatch(regex: "^M600", timeLeftAtMatch: 913.804278032729)
        ])
        paused.apply(event: stateEvent(printer: printerA, printing: true, paused: true, printTimeLeft: 900, matches: [
            TimeToFilamentMatch(regex: "^M600", timeLeftAtMatch: 913.804278032729)
        ]))
        XCTAssertEqual(paused.rows(includesApproximationPhrase: true).map(\.label), ["Time to Next Filament Change"])
        XCTAssertEqual(paused.rows(includesApproximationPhrase: true).map(\.value), ["Now"])
    }

    func testPluginsObjectWithoutThePluginClearsPreviousMatches() throws {
        var snapshot = printingSnapshot(printTimeLeft: 500, matches: [
            TimeToFilamentMatch(regex: "^M600", timeLeftAtMatch: 100)
        ])
        XCTAssertFalse(snapshot.rows(includesApproximationPhrase: true).isEmpty)

        let plugins = try jsonObject(#"{"PrintTimeGenius":{}}"#)
        let event = CurrentStateEvent(printerURL: printerA)
        event.printing = true
        event.paused = false
        event.progressPrintTime = 100
        event.progressPrintTimeLeft = 500
        event.parsePlugins(plugins: plugins)
        snapshot.apply(event: event)
        XCTAssertEqual(event.timeToFilamentMatches, [])
        XCTAssertTrue(snapshot.rows(includesApproximationPhrase: true).isEmpty)
    }

    func testFinishingTheJobClearsRows() {
        var snapshot = printingSnapshot(printTimeLeft: 500, matches: [
            TimeToFilamentMatch(regex: "^M600", timeLeftAtMatch: 100)
        ])
        let done = CurrentStateEvent(printerURL: printerA)
        done.printing = false
        done.progressCompletion = 100
        done.progressPrintTimeLeft = 0
        snapshot.apply(event: done)
        XCTAssertTrue(snapshot.rows(includesApproximationPhrase: true).isEmpty)

        snapshot = printingSnapshot(printTimeLeft: 500, matches: [
            TimeToFilamentMatch(regex: "^M600", timeLeftAtMatch: 100)
        ])
        snapshot.apply(event: stateEvent(printer: printerA, printing: false, paused: true, printTimeLeft: 500, matches: [
            TimeToFilamentMatch(regex: "^M600", timeLeftAtMatch: 100)
        ]))
        XCTAssertFalse(snapshot.rows(includesApproximationPhrase: true).isEmpty)
        let doneWhilePaused = CurrentStateEvent(printerURL: printerA)
        doneWhilePaused.printing = false
        doneWhilePaused.progressPrintTimeLeft = 0
        snapshot.apply(event: doneWhilePaused)
        XCTAssertTrue(snapshot.rows(includesApproximationPhrase: true).isEmpty)

        let started = CurrentStateEvent(printerURL: printerA)
        started.printing = true
        started.progressPrintTimeLeft = 0
        snapshot.apply(event: started)
        XCTAssertTrue(snapshot.rows(includesApproximationPhrase: true).isEmpty)
    }

    func testSwitchingPrintersDropsThePreviousPluginState() {
        var panel = TimeToFilamentPanelState()
        panel.noteSelectedPrinter(printerA)
        panel.apply(lines: defaultLines(), printerURL: printerA)
        panel.apply(event: stateEvent(printer: printerA, printing: true, paused: false, printTimeLeft: 3700, matches: [
            TimeToFilamentMatch(regex: "^M600", timeLeftAtMatch: 100)
        ]))
        XCTAssertFalse(panel.rows(includesApproximationPhrase: true).isEmpty)

        panel.noteSelectedPrinter(printerB)
        panel.clearContents()
        XCTAssertTrue(panel.rows(includesApproximationPhrase: true).isEmpty)

        panel.apply(lines: defaultLines(), printerURL: printerA)
        panel.apply(event: stateEvent(printer: printerA, printing: true, paused: false, printTimeLeft: 3700, matches: [
            TimeToFilamentMatch(regex: "^M600", timeLeftAtMatch: 100)
        ]))
        XCTAssertTrue(panel.rows(includesApproximationPhrase: true).isEmpty)

        panel.apply(lines: [], printerURL: printerB)
        panel.apply(event: stateEvent(printer: printerB, printing: true, paused: false, printTimeLeft: 1800, matches: []))
        XCTAssertTrue(panel.rows(includesApproximationPhrase: true).isEmpty)

        panel.noteSelectedPrinter(printerA)
        panel.apply(lines: [
            TimeToFilamentDisplayLine(description: "Color change", regex: "^M600", enabled: true)
        ], printerURL: printerA)
        panel.apply(event: stateEvent(printer: printerA, printing: true, paused: false, printTimeLeft: 900, matches: [
            TimeToFilamentMatch(regex: "^M600", timeLeftAtMatch: 300)
        ]))
        XCTAssertEqual(panel.rows(includesApproximationPhrase: false).map(\.label), ["Color change"])
        XCTAssertEqual(panel.rows(includesApproximationPhrase: false).map(\.value), [
            expectedValue(secondsUntil: 600, approximation: false)
        ])
    }

    func testClientPublishesInstalledAndMissingPlugins() throws {
        let withPlugin = try insertPrinter(defaultPrinter: true, hostname: "with-plugin")
        let withoutPlugin = try insertPrinter(defaultPrinter: false, hostname: "without-plugin")
        let client = OctoPrintClient(printerManager: printerManager, appConfiguration: AppConfiguration())
        let delegate = LinesDelegate()
        client.octoPrintSettingsDelegates.append(delegate)

        client.updatePrinterFromTimeToFilamentPlugin(printerID: withPlugin, plugins: try jsonObject(
            #"{"TimeToFilament":{"displayLines":[{"description":"Time to Next Filament Change","regex":"^M600","enabled":true,"enabledExternal":false}]}}"#
        ))
        client.updatePrinterFromTimeToFilamentPlugin(printerID: withoutPlugin, plugins: try jsonObject(
            #"{"PrintTimeGenius":{}}"#
        ))
        wait(for: [delegate.receivedTwo], timeout: 2)

        XCTAssertEqual(delegate.updates.map(\.printerURL), [
            withPlugin.uriRepresentation().absoluteString,
            withoutPlugin.uriRepresentation().absoluteString
        ])
        XCTAssertEqual(delegate.updates[0].lines, [
            TimeToFilamentDisplayLine(description: "Time to Next Filament Change", regex: "^M600", enabled: true)
        ])
        XCTAssertEqual(delegate.updates[1].lines, [])
        XCTAssertEqual(client.cachedTimeToFilamentLines(printerURL: withPlugin.uriRepresentation().absoluteString)?.count, 1)
        XCTAssertEqual(client.cachedTimeToFilamentLines(printerURL: withoutPlugin.uriRepresentation().absoluteString), [])
    }

    func testFullCurrentWithoutPluginsClearsTheLastMatch() throws {
        var snapshot = printingSnapshot(printTimeLeft: 400, matches: [
            TimeToFilamentMatch(regex: "^M600", timeLeftAtMatch: 100)
        ])
        XCTAssertFalse(snapshot.rows(includesApproximationPhrase: true).isEmpty)

        let current = try jsonObject(#"{"progress":{"printTime":100,"printTimeLeft":400}}"#)
        let event = CurrentStateEvent(printerURL: printerA)
        event.printing = true
        event.paused = false
        event.progressPrintTime = 100
        event.progressPrintTimeLeft = 400
        event.parseCurrentPlugins(current: current)
        snapshot.apply(event: event)
        XCTAssertEqual(event.timeToFilamentMatches, [])
        XCTAssertTrue(snapshot.rows(includesApproximationPhrase: true).isEmpty)

        let paused = CurrentStateEvent(printerURL: printerA)
        paused.printing = false
        paused.paused = true
        paused.progressPrintTimeLeft = 400
        snapshot = printingSnapshot(printTimeLeft: 400, matches: [
            TimeToFilamentMatch(regex: "^M600", timeLeftAtMatch: 100)
        ])
        paused.parseCurrentPlugins(current: current)
        snapshot.apply(event: paused)
        XCTAssertTrue(snapshot.rows(includesApproximationPhrase: true).isEmpty)
    }

    func testPartialPrintingEventKeepsMatchesUntilTheNextSnapshot() {
        var snapshot = printingSnapshot(printTimeLeft: 1000, matches: [
            TimeToFilamentMatch(regex: "^M600", timeLeftAtMatch: 100)
        ])
        let partial = CurrentStateEvent(printerURL: printerA)
        partial.printing = true
        partial.progressPrintTimeLeft = 400
        snapshot.apply(event: partial)
        XCTAssertNil(partial.timeToFilamentMatches)
        XCTAssertEqual(snapshot.rows(includesApproximationPhrase: false).map(\.label), ["Time to Next Filament Change"])
    }

    func testOutOfRangeEstimateDropsOnlyThatRow() throws {
        let plugins = try jsonObject(#"{"TimeToFilament":{"^M600":{"timeLeft":1e100},"^M601":{"timeLeft":50},"^; layer (\\d+)":{"timeLeft":"nope"}}}"#)
        let event = CurrentStateEvent(printerURL: printerA)
        event.printing = true
        event.paused = false
        event.progressPrintTime = 500
        event.progressPrintTimeLeft = 500
        event.parsePlugins(plugins: plugins)
        var snapshot = TimeToFilamentSnapshot()
        snapshot.apply(lines: defaultLines())
        snapshot.apply(event: event)
        XCTAssertEqual(snapshot.rows(includesApproximationPhrase: false).map(\.label), ["Time to Next Next Pause"])
    }

    func testFinalMinuteCountsSecondsWithoutChangingPrintTimeLeft() {
        let collapsed = UIUtils.secondsToTimeLeft(seconds: 59, includesApproximationPhrase: true, ifZero: "Now")
        let imminent = TimeToFilamentFormatting.value(secondsUntil: 59, includesApproximationPhrase: true)
        XCTAssertNotEqual(imminent, collapsed)
        XCTAssertFalse(imminent.isEmpty)
        XCTAssertNotEqual(imminent, UIUtils.secondsToETA(seconds: 59))

        let minute = UIUtils.secondsToTimeLeft(seconds: 60, includesApproximationPhrase: true, ifZero: "Now")
        XCTAssertEqual(TimeToFilamentFormatting.value(secondsUntil: 60, includesApproximationPhrase: true), minute)
        XCTAssertEqual(UIUtils.secondsToTimeLeft(seconds: 59, includesApproximationPhrase: true, ifZero: ""), collapsed)
        XCTAssertEqual(TimeToFilamentFormatting.value(secondsUntil: 0, includesApproximationPhrase: true), "Now")
        XCTAssertFalse(imminent.contains("·"))
    }

    func testOneCountdownStaysADurationAcrossAnHour() {
        let acrossAnHour = TimeToFilamentFormatting.value(secondsUntil: 3660, includesApproximationPhrase: true)
        XCTAssertFalse(acrossAnHour.contains("·"))
        XCTAssertNotEqual(acrossAnHour, UIUtils.secondsToETA(seconds: 3660))
        XCTAssertEqual(
            TimeToFilamentFormatting.value(secondsUntil: 3600, includesApproximationPhrase: false),
            UIUtils.secondsToTimeLeft(seconds: 3600, includesApproximationPhrase: false, ifZero: "Now")
        )

        let clockLabel = printingSnapshot(printTimeLeft: 400, matches: [
            TimeToFilamentMatch(regex: "^M600", timeLeftAtMatch: 100)
        ], lines: [
            TimeToFilamentDisplayLine(description: "Filament change at 18:00", regex: "^M600", enabled: true)
        ])
        XCTAssertEqual(clockLabel.rows(includesApproximationPhrase: true).map(\.label), ["Filament change at 18:00"])
        XCTAssertEqual(clockLabel.rows(includesApproximationPhrase: true).map(\.value), [
            TimeToFilamentFormatting.value(secondsUntil: 300, includesApproximationPhrase: true)
        ])
        XCTAssertNotEqual(
            clockLabel.rows(includesApproximationPhrase: false).map(\.value),
            [UIUtils.secondsToETA(seconds: 300)]
        )
    }

    func testRowFontsGrowAndNarrowAccessibilityTextStaysReadable() {
        let view = TimeToFilamentRowsView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.rows = []
        XCTAssertLessThan(fittedHeight(view), 1)

        let large = UITraitCollection(preferredContentSizeCategory: .large)
        let accessibility = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
        let largeFont = UIFont.preferredFont(forTextStyle: .body, compatibleWith: large)
        let accessibilityFont = UIFont.preferredFont(forTextStyle: .body, compatibleWith: accessibility)
        XCTAssertGreaterThan(accessibilityFont.pointSize, largeFont.pointSize)
        XCTAssertEqual(largeFont.pointSize, 17, accuracy: 0.5)
        view.rows = [
            TimeToFilamentRow(id: "1", label: "Time to Next Filament Change", value: "About 34 min · 4:42 PM"),
            TimeToFilamentRow(id: "2", label: "Time to Next Next Pause", value: "About 1 hr · 5:10 PM")
        ]
        view.applyFonts(compatibleWith: large)
        XCTAssertTrue(view.titleLabels[0].adjustsFontForContentSizeCategory)
        // The simulator's content-size category replaces a preferred font. Pin Large so the
        // baseline stays 17pt when the device is set above the default.
        pin(view, to: largeFont)
        XCTAssertEqual(view.valueLabels[0].font.pointSize, largeFont.pointSize, accuracy: 0.5)
        XCTAssertEqual(view.titleLabels[0].font.pointSize, largeFont.pointSize, accuracy: 0.5)

        let host = UIViewController()
        host.view.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
            view.topAnchor.constraint(equalTo: host.view.topAnchor)
        ])
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 900))
        window.rootViewController = host
        window.makeKeyAndVisible()
        if #available(iOS 17.0, *) {
            host.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        }
        host.view.layoutIfNeeded()
        pin(view, to: accessibilityFont)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        XCTAssertEqual(view.valueLabels[0].font.pointSize, accessibilityFont.pointSize, accuracy: 0.5)
        XCTAssertEqual(view.titleLabels[0].font.pointSize, view.valueLabels[0].font.pointSize, accuracy: 0.5)
        XCTAssertGreaterThan(view.valueLabels[0].font.pointSize, largeFont.pointSize)

        XCTAssertEqual(view.bounds.width, 320, accuracy: 1)
        XCTAssertEqual(view.titleLabels.count, 2)
        for label in view.titleLabels + view.valueLabels {
            XCTAssertGreaterThan(label.bounds.width, 40, label.text ?? "")
            XCTAssertGreaterThan(label.bounds.height, label.font.lineHeight * 0.8, label.text ?? "")
            XCTAssertTrue(wrappedTextFits(label), label.text ?? "")
        }
        XCTAssertGreaterThan(view.valueLabels[0].frame.minY, view.titleLabels[0].frame.maxY - 1, "value \(view.valueLabels[0].frame) title \(view.titleLabels[0].frame) view \(view.bounds) font \(view.titleLabels[0].font.pointSize)")
        let line = view.titleLabels[0].superview
        XCTAssertEqual(line?.accessibilityLabel, "Time to Next Filament Change, About 34 min · 4:42 PM")
        XCTAssertEqual(line?.isAccessibilityElement, true)
    }

    func testCountdownTickKeepsTheSameAccessibilityElement() throws {
        let view = TimeToFilamentRowsView(frame: CGRect(x: 0, y: 0, width: 320, height: 40))
        let filament = TimeToFilamentRow(id: "filament", label: "Layer", value: "About 34 min · 4:42 PM")
        let pause = TimeToFilamentRow(id: "pause", label: "Pause", value: "About 12 min · 4:20 PM")
        view.rows = [filament, pause]
        view.layout(fittingWidth: 320)
        view.layoutIfNeeded()
        let filamentElement = try XCTUnwrap(view.titleLabels[0].superview)
        let pauseElement = try XCTUnwrap(view.titleLabels[1].superview)
        let oneLineHeight = view.requiredHeight(for: 320)
        XCTAssertGreaterThan(oneLineHeight, 1)

        view.rows = [
            TimeToFilamentRow(id: "filament", label: "Layer", value: "About 33 min · 4:41 PM"),
            pause
        ]
        XCTAssertTrue(view.titleLabels[0].superview === filamentElement)
        XCTAssertTrue(filamentElement.superview === view)
        XCTAssertEqual(view.titleLabels[0].text, "Layer")
        XCTAssertEqual(view.valueLabels[0].text, "About 33 min · 4:41 PM")
        XCTAssertEqual(filamentElement.accessibilityLabel, "Layer, About 33 min · 4:41 PM")
        XCTAssertTrue(view.titleLabels[1].superview === pauseElement)
        XCTAssertEqual(view.requiredHeight(for: 320), oneLineHeight, accuracy: 0.5)
        let elementsAfterTick = try XCTUnwrap(view.accessibilityElements as? [UIView])
        XCTAssertTrue(elementsAfterTick[0] === filamentElement)
        XCTAssertTrue(elementsAfterTick[1] === pauseElement)

        view.rows = [
            TimeToFilamentRow(id: "pause", label: "Pause", value: "About 11 min · 4:19 PM"),
            TimeToFilamentRow(id: "filament", label: "Layer", value: "About 33 min · 4:41 PM")
        ]
        XCTAssertTrue(view.titleLabels[0].superview === pauseElement)
        XCTAssertTrue(view.titleLabels[1].superview === filamentElement)
        XCTAssertEqual(view.valueLabels[0].text, "About 11 min · 4:19 PM")
        XCTAssertEqual(pauseElement.accessibilityLabel, "Pause, About 11 min · 4:19 PM")
        let reordered = try XCTUnwrap(view.accessibilityElements as? [UIView])
        XCTAssertTrue(reordered[0] === pauseElement)
        XCTAssertTrue(reordered[1] === filamentElement)

        view.rows = [
            TimeToFilamentRow(id: "pause", label: "Pause", value: "About 11 min · 4:19 PM"),
            TimeToFilamentRow(id: "filament", label: "Layer", value: "About 33 min · 4:41 PM"),
            TimeToFilamentRow(id: "layer", label: "Next layer", value: "About 1 min · 4:09 PM")
        ]
        XCTAssertEqual(view.titleLabels.count, 3)
        XCTAssertTrue(view.titleLabels[0].superview === pauseElement)
        XCTAssertTrue(view.titleLabels[1].superview === filamentElement)
        let layerElement = try XCTUnwrap(view.titleLabels[2].superview)
        XCTAssertTrue(layerElement.superview === view)
        XCTAssertEqual(view.valueLabels[2].text, "About 1 min · 4:09 PM")
        XCTAssertEqual(layerElement.accessibilityLabel, "Next layer, About 1 min · 4:09 PM")

        view.rows = [
            TimeToFilamentRow(id: "filament", label: "Layer", value: "About 33 min · 4:41 PM")
        ]
        XCTAssertEqual(view.titleLabels.count, 1)
        XCTAssertTrue(view.titleLabels[0].superview === filamentElement)
        XCTAssertNil(pauseElement.superview)
        XCTAssertNil(layerElement.superview)
        XCTAssertEqual(view.valueLabels[0].text, "About 33 min · 4:41 PM")
        let remaining = try XCTUnwrap(view.accessibilityElements as? [UIView])
        XCTAssertEqual(remaining.count, 1)
        XCTAssertTrue(remaining[0] === filamentElement)
        let singleRowHeight = view.requiredHeight(for: 320)
        XCTAssertLessThan(singleRowHeight, oneLineHeight)

        view.rows = [
            TimeToFilamentRow(
                id: "filament",
                label: "Time to Next Filament Change",
                value: "About 1 day 12 hr · 11/15/26, 1:57 AM")
        ]
        XCTAssertTrue(view.titleLabels[0].superview === filamentElement)
        XCTAssertEqual(view.titleLabels[0].text, "Time to Next Filament Change")
        XCTAssertEqual(
            filamentElement.accessibilityLabel,
            "Time to Next Filament Change, About 1 day 12 hr · 11/15/26, 1:57 AM")
        XCTAssertGreaterThan(view.requiredHeight(for: 320), singleRowHeight + 10)
    }

    func testPrinterCellGrowsAndShrinksWithWrappedFilamentText() throws {
        let panel = try loadPrinterPanel(width: 320)
        let cell = try printTimeLeftCell(panel)
        XCTAssertTrue(panel.tableView.cellForRow(at: IndexPath(row: 4, section: 0)) === cell)
        let printTimeCell = try XCTUnwrap(panel.printTimeLabel.superview?.superview as? UITableViewCell)
        XCTAssertEqual(cell.bounds.height, printTimeCell.bounds.height, accuracy: 2)

        showFilament(panel, label: "Layer", secondsUntil: 34 * 60)
        let rowsView = try filamentRows(in: panel)
        let oneLine = cell.bounds.height
        XCTAssertGreaterThan(oneLine, printTimeCell.bounds.height)
        assertVisible(rowsView, in: cell)
        assertArrangementMatchesWidth(rowsView)

        let refreshes = panel.timeToFilamentHeightRefreshCount
        showFilament(panel, label: "Layer", secondsUntil: 33 * 60)
        XCTAssertEqual(panel.timeToFilamentHeightRefreshCount, refreshes)
        XCTAssertEqual(cell.bounds.height, oneLine, accuracy: 1)

        showFilament(panel, label: "Time to Next Filament Change", secondsUntil: 36 * 60 * 60)
        XCTAssertGreaterThan(cell.bounds.height, oneLine + 10)
        assertVisible(rowsView, in: cell)
        XCTAssertGreaterThan(rowsView.valueLabels[0].bounds.height, 10)
        XCTAssertGreaterThan(rowsView.valueLabels[0].frame.minY, rowsView.titleLabels[0].frame.maxY - 1, "value \(rowsView.valueLabels[0].frame) title \(rowsView.titleLabels[0].frame) rows \(rowsView.bounds) cell \(cell.bounds) table \(panel.tableView.bounds) text \(rowsView.titleLabels[0].text ?? "") / \(rowsView.valueLabels[0].text ?? "")")
        let wrapped = cell.bounds.height

        resize(panel, width: 900)
        assertVisible(rowsView, in: cell)
        assertArrangementMatchesWidth(rowsView)
        if !pairNeedsTwoLines(rowsView) {
            XCTAssertLessThan(cell.bounds.height, wrapped - 1)
        }

        resize(panel, width: 320)
        XCTAssertGreaterThan(cell.bounds.height, oneLine + 10)
        assertVisible(rowsView, in: cell)
        XCTAssertGreaterThan(rowsView.valueLabels[0].bounds.height, 10)
        XCTAssertGreaterThan(rowsView.titleLabels[0].bounds.height, 10)

        let beforeAccessibility = cell.bounds.height
        let accessibility = UIFont.preferredFont(
            forTextStyle: .body,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge))
        pin(rowsView, to: accessibility)
        panel.view.setNeedsLayout()
        panel.view.layoutIfNeeded()
        XCTAssertGreaterThan(cell.bounds.height, beforeAccessibility + 10)
        assertVisible(rowsView, in: cell)
        XCTAssertEqual(rowsView.valueLabels[0].font.pointSize, accessibility.pointSize, accuracy: 0.5)
    }

    func testPrinterPageKeepsItsViewportAboveThePageDots() throws {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle(for: PanelViewController.self))
        let tabs = try XCTUnwrap(storyboard.instantiateInitialViewController() as? UITabBarController)
        let navigation = try XCTUnwrap(tabs.viewControllers?.first as? UINavigationController)
        let panel = try XCTUnwrap(navigation.viewControllers.first as? PanelViewController)
        panel.loadViewIfNeeded()
        let subpanels = try XCTUnwrap(panel.subpanelsViewController)
        subpanels.loadViewIfNeeded()
        let pages = try XCTUnwrap(subpanels.children.compactMap { $0 as? UIPageViewController }.first)
        XCTAssertEqual(subpanels.view.backgroundColor?.cgColor.alpha, 0)

        for size in [CGSize(width: 320, height: 300), CGSize(width: 700, height: 200)] {
            subpanels.view.frame.size = size
            subpanels.view.setNeedsLayout()
            subpanels.view.layoutIfNeeded()

            XCTAssertEqual(pages.view.frame.width, size.width, accuracy: 0.5)
            XCTAssertGreaterThan(pages.view.frame.height, 0)
            XCTAssertLessThan(pages.view.frame.maxY, subpanels.pageControl.frame.minY)
            XCTAssertLessThanOrEqual(subpanels.pageControl.frame.maxY, subpanels.view.bounds.maxY + 0.5)
        }

        subpanels.view.frame.size = CGSize(width: 320, height: 300)
        subpanels.view.layoutIfNeeded()
        let printerPage = try XCTUnwrap(pages.viewControllers?.first as? PrinterSubpanelViewController)
        showFilament(printerPage, label: "Time remaining until the next filament change on this temperature tower", secondsUntil: 5)
        let rows = try filamentRows(in: printerPage)
        pin(rows, to: UIFont.preferredFont(
            forTextStyle: .body,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: .extraExtraExtraLarge)))
        printerPage.view.setNeedsLayout()
        printerPage.view.layoutIfNeeded()
        printerPage.tableView.scrollToRow(at: IndexPath(row: 4, section: 0), at: .middle, animated: false)
        printerPage.tableView.layoutIfNeeded()

        let title = try XCTUnwrap(rows.titleLabels.first)
        let value = try XCTUnwrap(rows.valueLabels.first)
        XCTAssertGreaterThan(value.frame.minY, title.frame.minY)
        let visibleRows = rows.convert(rows.bounds, to: subpanels.view)
        XCTAssertGreaterThanOrEqual(visibleRows.minY, pages.view.frame.minY)
        XCTAssertLessThanOrEqual(visibleRows.maxY, pages.view.frame.maxY)

        let history = try XCTUnwrap(
            pages.dataSource?.pageViewController(pages, viewControllerAfter: printerPage) as? TempHistoryViewController)
        pages.setViewControllers([history], direction: .forward, animated: false)
        pages.view.layoutIfNeeded()
        history.view.layoutIfNeeded()
        XCTAssertGreaterThan(history.lineChartView.bounds.height, 0)
        XCTAssertEqual(history.lineChartView.frame.maxY, history.view.safeAreaLayoutGuide.layoutFrame.maxY, accuracy: 0.5)
        let chartInPanel = history.lineChartView.convert(history.lineChartView.bounds, to: subpanels.view)
        XCTAssertLessThan(chartInPanel.maxY, subpanels.pageControl.frame.minY)
    }

    func testSettingsResponseKeepsOrderForPhoneAndAppleTV() throws {
        let server = try SettingsHTTPServer()
        defer { server.stop() }
        let layer = "^; layer (\\d+)"
        let lines = [
            (description: "Time to Next Next Pause", regex: "^M601", enabled: true),
            (description: "Time of Next Filament Change", regex: "^M600", enabled: false),
            (description: "Time to Next Layer", regex: layer, enabled: true)
        ]
        server.body = settingsJSON(lines: lines, extraPlugins: ["psucontrol": [String: Any]()])
        let printer = try configuredPrinter(hostname: "http://127.0.0.1:\(server.port)")
        let client = filamentClient()
        defer { client.disconnectFromServer() }
        let collector = SettingsCollector()
        client.octoPrintSettingsDelegates.append(collector)
        client.connectToServer(printer: printer)

        let printerURL = printer.objectID.uriRepresentation().absoluteString
        waitForSettings(collector) { published, url in
            url == printerURL && published.map(\.description) == lines.map(\.description)
        }
        let cached = try XCTUnwrap(client.cachedTimeToFilamentLines(printerURL: printerURL))
        XCTAssertEqual(cached.map(\.description), lines.map(\.description))
        XCTAssertEqual(cached.map(\.regex), lines.map(\.regex))
        XCTAssertEqual(cached.map(\.enabled), [true, false, true])
        XCTAssertTrue(try freshPrinterState(id: printer.objectID).psuControlInstalled)

        let event = stateEvent(printer: printerURL, printing: true, paused: false, printTimeLeft: 3700, matches: [
            TimeToFilamentMatch(regex: "^M600", timeLeftAtMatch: 100),
            TimeToFilamentMatch(regex: layer, timeLeftAtMatch: 3400),
            TimeToFilamentMatch(regex: "^M601", timeLeftAtMatch: 100)
        ])
        var phone = TimeToFilamentPanelState()
        phone.noteSelectedPrinter(printerURL)
        phone.apply(lines: cached, printerURL: printerURL)
        phone.apply(event: event)
        var appleTV = TimeToFilamentPanelState()
        appleTV.noteSelectedPrinter(printerURL)
        appleTV.apply(lines: cached, printerURL: printerURL)
        appleTV.apply(event: event)

        let phoneRows = phone.rows(includesApproximationPhrase: true)
        let tvRows = appleTV.rows(includesApproximationPhrase: false)
        XCTAssertEqual(phoneRows.map(\.label), ["Time to Next Next Pause", "Time to Next Layer"])
        XCTAssertEqual(tvRows.map(\.label), phoneRows.map(\.label))
        XCTAssertEqual(tvRows.map(\.id), phoneRows.map(\.id))
        XCTAssertEqual(phoneRows.map(\.value), [
            TimeToFilamentFormatting.value(secondsUntil: 3600, includesApproximationPhrase: true),
            TimeToFilamentFormatting.value(secondsUntil: 300, includesApproximationPhrase: true)
        ])
        XCTAssertEqual(tvRows.map(\.value), [
            TimeToFilamentFormatting.value(secondsUntil: 3600, includesApproximationPhrase: false),
            TimeToFilamentFormatting.value(secondsUntil: 300, includesApproximationPhrase: false)
        ])
        XCTAssertNotEqual(phoneRows.map(\.value), tvRows.map(\.value))
    }

    func testSuccessfulSettingsClearAMissingPluginAndAFailureKeepsTheSameServer() throws {
        let server = try SettingsHTTPServer()
        defer { server.stop() }
        let installed = [TimeToFilamentDisplayLine(description: "Time to Next Filament Change", regex: "^M600", enabled: true)]
        server.body = settingsJSON(lines: [(description: installed[0].description, regex: installed[0].regex, enabled: true)], extraPlugins: ["psucontrol": [String: Any]()])
        let printer = try configuredPrinter(hostname: "http://127.0.0.1:\(server.port)")
        let client = filamentClient()
        defer { client.disconnectFromServer() }
        let collector = SettingsCollector()
        client.octoPrintSettingsDelegates.append(collector)
        client.connectToServer(printer: printer)
        let printerURL = printer.objectID.uriRepresentation().absoluteString

        waitForSettings(collector) { lines, url in url == printerURL && lines == installed }
        XCTAssertTrue(try freshPrinterState(id: printer.objectID).psuControlInstalled)

        server.body = "{}"
        client.octoPrintSettingsUpdated()
        waitForSettings(collector) { lines, url in url == printerURL && lines.isEmpty }
        XCTAssertEqual(client.cachedTimeToFilamentLines(printerURL: printerURL), [])
        XCTAssertTrue(try freshPrinterState(id: printer.objectID).psuControlInstalled)

        server.body = settingsJSON(lines: [(description: installed[0].description, regex: installed[0].regex, enabled: true)])
        client.octoPrintSettingsUpdated()
        waitForSettings(collector) { lines, url in url == printerURL && lines == installed }

        server.body = #"{"plugins":{"PrintTimeGenius":{}}}"#
        client.octoPrintSettingsUpdated()
        waitForSettings(collector) { lines, url in url == printerURL && lines.isEmpty }
        XCTAssertEqual(client.cachedTimeToFilamentLines(printerURL: printerURL), [])

        server.body = settingsJSON(lines: [(description: installed[0].description, regex: installed[0].regex, enabled: true)])
        client.octoPrintSettingsUpdated()
        waitForSettings(collector) { lines, url in url == printerURL && lines == installed }
        let updates = collector.updates.count
        let served = server.settingsServed
        server.settingsStatus = 500
        client.octoPrintSettingsUpdated()
        waitUntil { server.settingsServed >= served + 1 }
        let quiet = expectation(description: "failed refresh does not publish")
        quiet.isInverted = true
        collector.onUpdate = {
            if collector.updates.count > updates {
                quiet.fulfill()
            }
        }
        wait(for: [quiet], timeout: 0.5)
        XCTAssertEqual(collector.updates.count, updates)
        XCTAssertEqual(client.cachedTimeToFilamentLines(printerURL: printerURL), installed)
    }

    func testHostnameEditKeepsTheLateResponseOffTheSamePrinterObject() throws {
        let oldServer = try SettingsHTTPServer()
        let newServer = try SettingsHTTPServer()
        defer {
            oldServer.stop()
            newServer.stop()
        }
        oldServer.body = settingsJSON(lines: [(description: "From A", regex: "^M600", enabled: true)])
        newServer.body = settingsJSON(lines: [(description: "From B", regex: "^M601", enabled: true)])
        oldServer.holdNextSettingsResponse()
        let printer = try configuredPrinter(hostname: "http://127.0.0.1:\(oldServer.port)")
        let client = filamentClient()
        defer { client.disconnectFromServer() }
        let collector = SettingsCollector()
        client.octoPrintSettingsDelegates.append(collector)
        client.connectToServer(printer: printer)
        let printerURL = printer.objectID.uriRepresentation().absoluteString
        waitUntil { oldServer.settingsRequests == 1 }

        printer.hostname = "http://127.0.0.1:\(newServer.port)"
        try persistentContainer.viewContext.save()
        client.connectToServer(printer: printer)
        waitForSettings(collector) { lines, url in
            url == printerURL && lines.map(\.description) == ["From B"]
        }

        let late = expectation(description: "previous hostname settings stay unpublished")
        late.isInverted = true
        collector.onUpdate = {
            if collector.updates.contains(where: { $0.lines.contains { $0.description == "From A" } }) {
                late.fulfill()
            }
        }
        oldServer.releaseHold()
        wait(for: [late], timeout: 1)
        XCTAssertFalse(collector.updates.contains { $0.lines.contains { $0.description == "From A" } })
        XCTAssertEqual(client.cachedTimeToFilamentLines(printerURL: printerURL)?.map(\.description), ["From B"])
    }

    func testPrinterSwitchIgnoresThePreviousServersLateSettings() throws {
        let serverA = try SettingsHTTPServer()
        let serverB = try SettingsHTTPServer()
        defer {
            serverA.stop()
            serverB.stop()
        }
        serverA.body = settingsJSON(lines: [(description: "From A", regex: "^M600", enabled: true)])
        serverB.body = settingsJSON(lines: [(description: "From B", regex: "^M601", enabled: true)])
        serverA.holdNextSettingsResponse()
        let printerA = try configuredPrinter(hostname: "http://127.0.0.1:\(serverA.port)")
        let printerB = try configuredPrinter(hostname: "http://127.0.0.1:\(serverB.port)", defaultPrinter: false)
        let client = filamentClient()
        defer { client.disconnectFromServer() }
        let collector = SettingsCollector()
        client.octoPrintSettingsDelegates.append(collector)
        client.connectToServer(printer: printerA)
        let urlA = printerA.objectID.uriRepresentation().absoluteString
        let urlB = printerB.objectID.uriRepresentation().absoluteString
        waitUntil { serverA.settingsRequests == 1 }

        client.connectToServer(printer: printerB)
        waitForSettings(collector) { lines, url in
            url == urlB && lines.map(\.description) == ["From B"]
        }

        let late = expectation(description: "previous printer settings stay unpublished")
        late.isInverted = true
        collector.onUpdate = {
            if collector.updates.contains(where: { $0.printerURL == urlA && $0.lines.contains { $0.description == "From A" } }) {
                late.fulfill()
            }
        }
        serverA.releaseHold()
        wait(for: [late], timeout: 1)
        XCTAssertNil(client.cachedTimeToFilamentLines(printerURL: urlA))
        XCTAssertEqual(client.cachedTimeToFilamentLines(printerURL: urlB)?.map(\.description), ["From B"])
        XCTAssertFalse(collector.updates.contains { $0.printerURL == urlA })
    }

    /// Same printer object, edited hostname. A is already inside apply when B publishes.
    func testHostnameEditDuringApplyKeepsTheNewServer() throws {
        let oldServer = try SettingsHTTPServer()
        let newServer = try SettingsHTTPServer()
        defer {
            oldServer.stop()
            newServer.stop()
        }
        oldServer.body = settingsJSON(lines: [(description: "From A", regex: "^M600", enabled: true)])
        newServer.body = settingsJSON(lines: [(description: "From B", regex: "^M601", enabled: true)])
        oldServer.holdNextSettingsResponse()
        let printer = try configuredPrinter(hostname: "http://127.0.0.1:\(oldServer.port)")
        let client = filamentClient()
        defer { client.disconnectFromServer() }
        let collector = SettingsCollector()
        client.octoPrintSettingsDelegates.append(collector)
        let gate = ApplyGate()
        defer { gate.resume() }
        client.timeToFilamentService.beforeApply = { _ in gate.parkFirstApply() }
        client.connectToServer(printer: printer)
        let printerURL = printer.objectID.uriRepresentation().absoluteString
        waitUntil { oldServer.settingsRequests == 1 }
        oldServer.releaseHold()
        guard waitUntilParked(gate) else {
            XCTFail("the first settings body did not reach apply")
            return
        }

        printer.hostname = "http://127.0.0.1:\(newServer.port)"
        try persistentContainer.viewContext.save()
        client.connectToServer(printer: printer)
        waitForSettings(collector) { lines, url in
            url == printerURL && lines.map(\.description) == ["From B"]
        }
        let published = collector.updates.count
        gate.resume()
        expectNoFurtherSettings(collector, after: published)
        XCTAssertFalse(collector.updates.contains { $0.lines.contains { $0.description == "From A" } })
        XCTAssertEqual(client.cachedTimeToFilamentLines(printerURL: printerURL)?.map(\.description), ["From B"])
        assertPhoneAndTVShow(updates: collector.updates, printerURL: printerURL, label: "From B", regex: "^M601")
    }

    func testDisconnectDropsTheResponseThatHasNotCommitted() throws {
        let server = try SettingsHTTPServer()
        defer { server.stop() }
        server.body = settingsJSON(lines: [(description: "Kept", regex: "^M600", enabled: true)])
        let printer = try configuredPrinter(hostname: "http://127.0.0.1:\(server.port)")
        let client = filamentClient()
        defer { client.disconnectFromServer() }
        let collector = SettingsCollector()
        client.octoPrintSettingsDelegates.append(collector)
        client.connectToServer(printer: printer)
        let printerURL = printer.objectID.uriRepresentation().absoluteString
        waitForSettings(collector) { lines, url in
            url == printerURL && lines.map(\.description) == ["Kept"]
        }

        let gate = ApplyGate()
        defer { gate.resume() }
        client.timeToFilamentService.beforeApply = { _ in gate.parkFirstApply() }
        server.body = settingsJSON(lines: [(description: "Stale", regex: "^M601", enabled: true)])
        client.octoPrintSettingsUpdated()
        guard waitUntilParked(gate) else {
            XCTFail("the settings body did not reach apply")
            return
        }
        client.disconnectFromServer()
        let published = collector.updates.count
        gate.resume()
        expectNoFurtherSettings(collector, after: published)
        XCTAssertFalse(collector.updates.contains { $0.lines.contains { $0.description == "Stale" } })
        XCTAssertEqual(client.cachedTimeToFilamentLines(printerURL: printerURL)?.map(\.description), ["Kept"])
        assertPhoneAndTVShow(updates: collector.updates, printerURL: printerURL, label: "Kept", regex: "^M600")
    }

    func testPrinterSwitchDropsTheResponseThatHasNotCommitted() throws {
        let serverA = try SettingsHTTPServer()
        let serverB = try SettingsHTTPServer()
        defer {
            serverA.stop()
            serverB.stop()
        }
        serverA.body = settingsJSON(lines: [(description: "Kept", regex: "^M600", enabled: true)])
        serverB.body = settingsJSON(lines: [(description: "From B", regex: "^M601", enabled: true)])
        let printerA = try configuredPrinter(hostname: "http://127.0.0.1:\(serverA.port)")
        let printerB = try configuredPrinter(hostname: "http://127.0.0.1:\(serverB.port)", defaultPrinter: false)
        let client = filamentClient()
        defer { client.disconnectFromServer() }
        let collector = SettingsCollector()
        client.octoPrintSettingsDelegates.append(collector)
        client.connectToServer(printer: printerA)
        let urlA = printerA.objectID.uriRepresentation().absoluteString
        let urlB = printerB.objectID.uriRepresentation().absoluteString
        waitForSettings(collector) { lines, url in
            url == urlA && lines.map(\.description) == ["Kept"]
        }

        let gate = ApplyGate()
        defer { gate.resume() }
        client.timeToFilamentService.beforeApply = { _ in gate.parkFirstApply() }
        serverA.body = settingsJSON(lines: [(description: "Stale", regex: "^M600", enabled: true)])
        client.octoPrintSettingsUpdated()
        guard waitUntilParked(gate) else {
            XCTFail("the settings body did not reach apply")
            return
        }

        client.connectToServer(printer: printerB)
        waitForSettings(collector) { lines, url in
            url == urlB && lines.map(\.description) == ["From B"]
        }
        let published = collector.updates.count
        gate.resume()
        expectNoFurtherSettings(collector, after: published)
        XCTAssertFalse(collector.updates.contains { $0.lines.contains { $0.description == "Stale" } })
        XCTAssertEqual(client.cachedTimeToFilamentLines(printerURL: urlA)?.map(\.description), ["Kept"])
        XCTAssertEqual(client.cachedTimeToFilamentLines(printerURL: urlB)?.map(\.description), ["From B"])
    }

    func testUIApplyAfterSwitchDropsTheAcceptedLines() throws {
        let serverA = try SettingsHTTPServer()
        let serverB = try SettingsHTTPServer()
        defer {
            serverA.stop()
            serverB.stop()
        }
        serverA.body = settingsJSON(lines: [(description: "Late", regex: "^M600", enabled: true)])
        serverB.holdNextSettingsResponse()
        serverB.body = settingsJSON(lines: [(description: "From B", regex: "^M601", enabled: true)])
        let printerA = try configuredPrinter(hostname: "http://127.0.0.1:\(serverA.port)")
        let printerB = try configuredPrinter(hostname: "http://127.0.0.1:\(serverB.port)", defaultPrinter: false)
        let client = filamentClient()
        defer { client.disconnectFromServer() }
        let collector = SettingsCollector()
        client.octoPrintSettingsDelegates.append(collector)
        client.connectToServer(printer: printerA)
        let urlA = printerA.objectID.uriRepresentation().absoluteString
        let urlB = printerB.objectID.uriRepresentation().absoluteString
        waitForSettings(collector) { lines, url in
            url == urlA && lines.map(\.description) == ["Late"]
        }

        client.connectToServer(printer: printerB)
        var panel = TimeToFilamentPanelState()
        panel.noteSelectedPrinter(urlB)
        panel.apply(lines: [TimeToFilamentDisplayLine(description: "Ender", regex: "^M601", enabled: true)], printerURL: urlB)
        let captured = collector.updates.first { $0.printerURL == urlA }?.lines
        panel.applyDeliveredLines(
            printerURL: urlA,
            selectedPrinterURL: urlB,
            currentLines: client.timeToFilamentService.linesIfCurrent(printerURL: urlA)
        )
        XCTAssertEqual(captured?.map(\.description), ["Late"])
        XCTAssertNil(client.timeToFilamentService.linesIfCurrent(printerURL: urlA))
        XCTAssertEqual(panel.rows(includesApproximationPhrase: true).map(\.label), [])
        panel.apply(event: stateEvent(printer: urlB, printing: true, paused: false, printTimeLeft: 400, matches: [
            TimeToFilamentMatch(regex: "^M601", timeLeftAtMatch: 100)
        ]))
        XCTAssertEqual(panel.rows(includesApproximationPhrase: false).map(\.label), ["Ender"])
    }

    func testUIApplyAfterHostnameEditDropsTheAcceptedLines() throws {
        let oldServer = try SettingsHTTPServer()
        let newServer = try SettingsHTTPServer()
        defer {
            oldServer.stop()
            newServer.stop()
        }
        oldServer.body = settingsJSON(lines: [(description: "From A", regex: "^M600", enabled: true)])
        newServer.holdNextSettingsResponse()
        newServer.body = settingsJSON(lines: [(description: "From B", regex: "^M601", enabled: true)])
        let printer = try configuredPrinter(hostname: "http://127.0.0.1:\(oldServer.port)")
        let client = filamentClient()
        defer { client.disconnectFromServer() }
        let collector = SettingsCollector()
        client.octoPrintSettingsDelegates.append(collector)
        client.connectToServer(printer: printer)
        let printerURL = printer.objectID.uriRepresentation().absoluteString
        waitForSettings(collector) { lines, url in
            url == printerURL && lines.map(\.description) == ["From A"]
        }

        printer.hostname = "http://127.0.0.1:\(newServer.port)"
        try persistentContainer.viewContext.save()
        client.connectToServer(printer: printer)
        var panel = TimeToFilamentPanelState()
        panel.applyDeliveredLines(
            printerURL: printerURL,
            selectedPrinterURL: printerURL,
            currentLines: client.timeToFilamentService.linesIfCurrent(printerURL: printerURL)
        )
        panel.apply(event: stateEvent(printer: printerURL, printing: true, paused: false, printTimeLeft: 400, matches: [
            TimeToFilamentMatch(regex: "^M600", timeLeftAtMatch: 100)
        ]))
        XCTAssertTrue(collector.updates.contains { $0.lines.map(\.description) == ["From A"] })
        XCTAssertEqual(panel.rows(includesApproximationPhrase: true).map(\.label), [])
        XCTAssertEqual(client.timeToFilamentService.linesIfCurrent(printerURL: printerURL), [])
    }

    func testQueuedDeliveryDoesNotPublishAfterDisconnect() throws {
        let server = try SettingsHTTPServer()
        defer { server.stop() }
        let lines = [(description: "Kept", regex: "^M600", enabled: true)]
        server.body = settingsJSON(lines: lines)
        let printer = try configuredPrinter(hostname: "http://127.0.0.1:\(server.port)")
        let client = filamentClient()
        defer { client.disconnectFromServer() }
        let collector = SettingsCollector()
        client.octoPrintSettingsDelegates.append(collector)
        client.beforeDeliveringTimeToFilament = {
            client.beforeDeliveringTimeToFilament = nil
            client.disconnectFromServer()
        }
        client.connectToServer(printer: printer)
        let printerURL = printer.objectID.uriRepresentation().absoluteString
        let kept = [TimeToFilamentDisplayLine(description: "Kept", regex: "^M600", enabled: true)]
        waitUntil { client.cachedTimeToFilamentLines(printerURL: printerURL) == kept }
        expectNoFurtherSettings(collector, after: 0)
        XCTAssertTrue(collector.updates.isEmpty)
        XCTAssertEqual(client.cachedTimeToFilamentLines(printerURL: printerURL), kept)
    }

    func testQueuedDeliveryDoesNotPublishAfterPrinterSwitch() throws {
        let serverA = try SettingsHTTPServer()
        let serverB = try SettingsHTTPServer()
        defer {
            serverA.stop()
            serverB.stop()
        }
        serverA.body = settingsJSON(lines: [(description: "Kept", regex: "^M600", enabled: true)])
        serverB.body = settingsJSON(lines: [(description: "From B", regex: "^M601", enabled: true)])
        let printerA = try configuredPrinter(hostname: "http://127.0.0.1:\(serverA.port)")
        let printerB = try configuredPrinter(hostname: "http://127.0.0.1:\(serverB.port)", defaultPrinter: false)
        let client = filamentClient()
        defer { client.disconnectFromServer() }
        let collector = SettingsCollector()
        client.octoPrintSettingsDelegates.append(collector)
        let urlA = printerA.objectID.uriRepresentation().absoluteString
        let urlB = printerB.objectID.uriRepresentation().absoluteString
        client.beforeDeliveringTimeToFilament = {
            client.beforeDeliveringTimeToFilament = nil
            client.disconnectFromServer()
        }
        client.connectToServer(printer: printerA)
        let kept = [TimeToFilamentDisplayLine(description: "Kept", regex: "^M600", enabled: true)]
        waitUntil { client.cachedTimeToFilamentLines(printerURL: urlA) == kept }
        XCTAssertTrue(collector.updates.isEmpty)
        client.connectToServer(printer: printerB)
        waitForSettings(collector) { lines, url in
            url == urlB && lines.map(\.description) == ["From B"]
        }
        XCTAssertFalse(collector.updates.contains { $0.printerURL == urlA })
        XCTAssertEqual(client.cachedTimeToFilamentLines(printerURL: urlA), kept)
        XCTAssertEqual(client.cachedTimeToFilamentLines(printerURL: urlB)?.map(\.description), ["From B"])
    }

    private func configuredPrinter(hostname: String, defaultPrinter: Bool = true) throws -> Printer {
        let id = try insertPrinter(defaultPrinter: defaultPrinter, hostname: hostname)
        let printer = persistentContainer.viewContext.object(with: id) as! Printer
        printer.apiKey = "test-key"
        try persistentContainer.viewContext.save()
        return printer
    }

    private func filamentClient() -> OctoPrintClient {
        OctoPrintClient(printerManager: printerManager, appConfiguration: AppConfiguration())
    }

    private func settingsJSON(lines: [(description: String, regex: String, enabled: Bool)], extraPlugins: [String: Any] = [:]) -> String {
        var plugins = extraPlugins
        plugins["TimeToFilament"] = [
            "displayLines": lines.map {
                ["description": $0.description, "regex": $0.regex, "enabled": $0.enabled, "enabledExternal": false] as [String: Any]
            }
        ]
        let data = try! JSONSerialization.data(withJSONObject: ["plugins": plugins])
        return String(decoding: data, as: UTF8.self)
    }

    private func waitForSettings(_ collector: SettingsCollector, timeout: TimeInterval = 5, after baseline: Int? = nil, where predicate: @escaping ([TimeToFilamentDisplayLine], String) -> Bool) {
        let start = baseline ?? collector.updates.count
        let done = expectation(description: "settings published")
        var fulfilled = false
        let finish = {
            guard !fulfilled, collector.updates.dropFirst(start).contains(where: { predicate($0.lines, $0.printerURL) }) else { return }
            fulfilled = true
            done.fulfill()
        }
        collector.onUpdate = finish
        finish()
        wait(for: [done], timeout: timeout)
        collector.onUpdate = nil
    }

    /// XCTest's waiter drains the main queue. A direct `RunLoop.run` did not, so the settings
    /// callback stayed blocked in the main-context hop and never reached apply.
    private func waitUntilParked(_ gate: ApplyGate, timeout: TimeInterval = 5) -> Bool {
        if gate.isParked() { return true }
        let done = expectation(description: "apply parked")
        let timer = Timer(timeInterval: 0.01, repeats: true) { timer in
            if gate.isParked() {
                timer.invalidate()
                done.fulfill()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        wait(for: [done], timeout: timeout)
        timer.invalidate()
        return gate.isParked()
    }

    private func expectNoFurtherSettings(_ collector: SettingsCollector, after published: Int) {
        let late = expectation(description: "stale settings stay unpublished")
        late.isInverted = true
        collector.onUpdate = {
            if collector.updates.count > published {
                late.fulfill()
            }
        }
        wait(for: [late], timeout: 1)
        collector.onUpdate = nil
    }

    private func assertPhoneAndTVShow(updates: [SettingsCollector.Update], printerURL: String, label: String, regex: String, file: StaticString = #filePath, line: UInt = #line) {
        let event = stateEvent(printer: printerURL, printing: true, paused: false, printTimeLeft: 3700, matches: [
            TimeToFilamentMatch(regex: regex, timeLeftAtMatch: 100)
        ])
        func rendered(_ includesApproximationPhrase: Bool) -> (labels: [String], values: [String]) {
            var panel = TimeToFilamentPanelState()
            panel.noteSelectedPrinter(printerURL)
            for update in updates where update.printerURL == printerURL {
                panel.apply(lines: update.lines, printerURL: printerURL)
            }
            panel.apply(event: event)
            let rows = panel.rows(includesApproximationPhrase: includesApproximationPhrase)
            return (rows.map(\.label), rows.map(\.value))
        }
        let phone = rendered(true)
        let tv = rendered(false)
        XCTAssertEqual(phone.labels, [label], file: file, line: line)
        XCTAssertEqual(tv.labels, [label], file: file, line: line)
        XCTAssertEqual(phone.values, [TimeToFilamentFormatting.value(secondsUntil: 3600, includesApproximationPhrase: true)], file: file, line: line)
        XCTAssertEqual(tv.values, [TimeToFilamentFormatting.value(secondsUntil: 3600, includesApproximationPhrase: false)], file: file, line: line)
    }

    private func waitUntil(timeout: TimeInterval = 5, _ condition: @escaping () -> Bool) {
        if condition() { return }
        let done = expectation(description: "condition")
        let timer = Timer(timeInterval: 0.02, repeats: true) { timer in
            if condition() {
                timer.invalidate()
                done.fulfill()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        wait(for: [done], timeout: timeout)
        timer.invalidate()
    }

    private func jsonObject(_ json: String) throws -> NSDictionary {
        let object = try JSONSerialization.jsonObject(with: Data(json.utf8))
        return try XCTUnwrap(object as? NSDictionary)
    }

    private func printingSnapshot(printTimeLeft: Int, matches: [TimeToFilamentMatch], lines: [TimeToFilamentDisplayLine]? = nil) -> TimeToFilamentSnapshot {
        var snapshot = TimeToFilamentSnapshot()
        snapshot.apply(lines: lines ?? defaultLines())
        snapshot.apply(event: stateEvent(printer: printerA, printing: true, paused: false, printTimeLeft: printTimeLeft, matches: matches))
        return snapshot
    }

    private func defaultLines() -> [TimeToFilamentDisplayLine] {
        [
            TimeToFilamentDisplayLine(description: "Time to Next Layer", regex: "^; layer (\\d+)", enabled: true),
            TimeToFilamentDisplayLine(description: "Time to Next Filament Change", regex: "^M600", enabled: true),
            TimeToFilamentDisplayLine(description: "Time of Next Filament Change", regex: "^M600", enabled: false),
            TimeToFilamentDisplayLine(description: "Time to Next Next Pause", regex: "^M601", enabled: true)
        ]
    }

    private func stateEvent(printer: String, printing: Bool, paused: Bool, printTimeLeft: Int?, printTime: Int? = nil, matches: [TimeToFilamentMatch]?) -> CurrentStateEvent {
        let event = CurrentStateEvent(printerURL: printer)
        event.printing = printing
        event.paused = paused
        event.progressPrintTime = printTime ?? printTimeLeft
        event.progressPrintTimeLeft = printTimeLeft
        event.timeToFilamentMatches = matches
        return event
    }

    private func expectedValue(secondsUntil: Int, approximation: Bool) -> String {
        TimeToFilamentFormatting.value(secondsUntil: secondsUntil, includesApproximationPhrase: approximation)
    }

    private func pin(_ view: TimeToFilamentRowsView, to font: UIFont) {
        for label in view.titleLabels + view.valueLabels {
            label.adjustsFontForContentSizeCategory = false
            label.font = font
        }
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    private func loadPrinterPanel(width: CGFloat) throws -> PrinterSubpanelViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle(for: PrinterSubpanelViewController.self))
        let panel = try XCTUnwrap(storyboard.instantiateViewController(withIdentifier: "PrinterSubpanelViewController") as? PrinterSubpanelViewController)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 900))
        window.rootViewController = panel
        window.makeKeyAndVisible()
        panel.loadViewIfNeeded()
        let cleared = expectation(description: "initial printer panel clear")
        DispatchQueue.main.async { cleared.fulfill() }
        wait(for: [cleared], timeout: 2)
        return panel
    }

    private func printTimeLeftCell(_ panel: PrinterSubpanelViewController) throws -> UITableViewCell {
        try XCTUnwrap(panel.printTimeLeftTextLabel.superview?.superview as? UITableViewCell)
    }

    private func filamentRows(in panel: PrinterSubpanelViewController) throws -> TimeToFilamentRowsView {
        let cell = try printTimeLeftCell(panel)
        let rows = cell.contentView.subviews.compactMap { $0 as? TimeToFilamentRowsView }
        return try XCTUnwrap(rows.first)
    }

    private func showFilament(_ panel: PrinterSubpanelViewController, label: String, secondsUntil: Int) {
        let regex = "^M600"
        panel.timeToFilament.noteSelectedPrinter(printerA)
        panel.timeToFilament.apply(lines: [
            TimeToFilamentDisplayLine(description: label, regex: regex, enabled: true)
        ], printerURL: printerA)
        panel.timeToFilament.apply(event: stateEvent(
            printer: printerA,
            printing: true,
            paused: false,
            printTimeLeft: secondsUntil + 100,
            matches: [TimeToFilamentMatch(regex: regex, timeLeftAtMatch: 100)]))
        panel.renderTimeToFilament()
        panel.view.layoutIfNeeded()
    }

    private func resize(_ panel: PrinterSubpanelViewController, width: CGFloat) {
        panel.view.window?.frame = CGRect(x: 0, y: 0, width: width, height: 900)
        panel.view.frame = CGRect(x: 0, y: 0, width: width, height: 900)
        panel.view.setNeedsLayout()
        panel.view.layoutIfNeeded()
    }

    private func pairNeedsTwoLines(_ rows: TimeToFilamentRowsView) -> Bool {
        guard let title = rows.titleLabels.first, let value = rows.valueLabels.first, rows.bounds.width > 1 else {
            return false
        }
        let titleWidth = ceil((title.text as NSString?)?.size(withAttributes: [.font: title.font]).width ?? 0)
        let valueWidth = ceil((value.text as NSString?)?.size(withAttributes: [.font: value.font]).width ?? 0)
        return titleWidth + valueWidth + 8 > rows.bounds.width
    }

    private func assertArrangementMatchesWidth(_ rows: TimeToFilamentRowsView, file: StaticString = #filePath, line: UInt = #line) {
        guard let title = rows.titleLabels.first, let value = rows.valueLabels.first else { return }
        if pairNeedsTwoLines(rows) {
            XCTAssertGreaterThan(value.frame.minY, title.frame.maxY - 1, file: file, line: line)
            XCTAssertEqual(value.textAlignment, .natural, file: file, line: line)
            XCTAssertEqual(value.frame.minX, title.frame.minX, accuracy: 1, file: file, line: line)
        } else {
            XCTAssertLessThan(value.frame.minY, title.frame.maxY, file: file, line: line)
            XCTAssertEqual(value.textAlignment, .right, file: file, line: line)
            XCTAssertGreaterThan(value.frame.minX, title.frame.maxX, file: file, line: line)
        }
    }

    private func assertVisible(_ rows: TimeToFilamentRowsView, in cell: UITableViewCell, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(rows.titleLabels.count, rows.valueLabels.count, file: file, line: line)
        for label in rows.titleLabels + rows.valueLabels {
            let frame = label.convert(label.bounds, to: cell)
            XCTAssertGreaterThan(frame.width, 40, label.text ?? "", file: file, line: line)
            XCTAssertGreaterThan(frame.height, 10, label.text ?? "", file: file, line: line)
            XCTAssertLessThanOrEqual(frame.maxY, cell.bounds.height + 1, label.text ?? "", file: file, line: line)
            XCTAssertTrue(wrappedTextFits(label), label.text ?? "", file: file, line: line)
        }
    }

    private func fittedHeight(_ view: TimeToFilamentRowsView) -> CGFloat {
        view.systemLayoutSizeFitting(
            CGSize(width: 320, height: 0),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
    }

    private func wrappedTextFits(_ label: UILabel) -> Bool {
        guard let text = label.text, label.bounds.width > 1, label.bounds.height > 1 else {
            return false
        }
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: label.font as Any],
            context: nil
        )
        return ceil(rect.height) <= label.bounds.height + 2
    }
}

private final class LinesDelegate: OctoPrintSettingsDelegate {
    struct Update {
        let lines: [TimeToFilamentDisplayLine]
        let printerURL: String
    }

    private(set) var updates: [Update] = []
    let receivedTwo = XCTestExpectation(description: "both printer settings published")

    func timeToFilamentLinesChanged(_ lines: [TimeToFilamentDisplayLine], printerURL: String) {
        updates.append(Update(lines: lines, printerURL: printerURL))
        if updates.count == 2 {
            receivedTwo.fulfill()
        }
    }
}

/// Parks the first settings apply inside `condition.wait` before the test starts the newer one.
/// A fulfill-then-wait gate can resume the test before the apply is parked, so the stale body wins first.
private final class ApplyGate {
    private let condition = NSCondition()
    private var parked = false
    private var release = false
    private var seen = false

    func parkFirstApply() {
        condition.lock()
        if seen {
            condition.unlock()
            return
        }
        seen = true
        parked = true
        condition.signal()
        while !release {
            condition.wait()
        }
        condition.unlock()
    }

    /// True only after the first apply has released this lock by waiting.
    func isParked() -> Bool {
        condition.lock()
        defer { condition.unlock() }
        return parked
    }

    func resume() {
        condition.lock()
        release = true
        condition.signal()
        condition.unlock()
    }
}

private final class SettingsCollector: OctoPrintSettingsDelegate {
    struct Update {
        let lines: [TimeToFilamentDisplayLine]
        let printerURL: String
    }

    private(set) var updates: [Update] = []
    var onUpdate: (() -> Void)?

    func timeToFilamentLinesChanged(_ lines: [TimeToFilamentDisplayLine], printerURL: String) {
        updates.append(Update(lines: lines, printerURL: printerURL))
        onUpdate?()
    }
}

/// One thread per connection, so a held `/api/settings` does not stall the printer-state requests
/// that `connectToServer` sends beside it.
private final class SettingsHTTPServer {
    private let listenFD: Int32
    private let lock = NSLock()
    private var stopped = false
    private var storedBody = "{}"
    private var storedStatus = 200
    private var hold = false
    private var waiter: DispatchSemaphore?
    private var settingsRequestCount = 0
    private var settingsServedCount = 0
    private var recordedTargets: [String] = []
    let port: UInt16

    var body: String {
        get { lock.lock(); defer { lock.unlock() }; return storedBody }
        set { lock.lock(); storedBody = newValue; lock.unlock() }
    }

    var settingsStatus: Int {
        get { lock.lock(); defer { lock.unlock() }; return storedStatus }
        set { lock.lock(); storedStatus = newValue; lock.unlock() }
    }

    var settingsRequests: Int {
        lock.lock(); defer { lock.unlock() }; return settingsRequestCount
    }

    var settingsServed: Int {
        lock.lock(); defer { lock.unlock() }; return settingsServedCount
    }

    var targets: [String] {
        lock.lock(); defer { lock.unlock() }; return recordedTargets
    }

    init() throws {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        if fd < 0 { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout.size(ofValue: yes)))
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout.size(ofValue: yes)))
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if bound != 0 || listen(fd, 32) != 0 {
            close(fd)
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        var resolved = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &resolved) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(fd, $0, &length)
            }
        }
        if named != 0 {
            close(fd)
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        listenFD = fd
        port = CFSwapInt16BigToHost(resolved.sin_port)
        Thread.detachNewThread { [weak self] in
            self?.acceptLoop()
        }
    }

    deinit { stop() }

    func holdNextSettingsResponse() {
        lock.lock()
        hold = true
        waiter = DispatchSemaphore(value: 0)
        lock.unlock()
    }

    func releaseHold() {
        lock.lock()
        let waiter = self.waiter
        hold = false
        lock.unlock()
        waiter?.signal()
    }

    func stop() {
        lock.lock()
        if stopped {
            lock.unlock()
            return
        }
        stopped = true
        let fd = listenFD
        let waiter = self.waiter
        lock.unlock()
        waiter?.signal()
        close(fd)
    }

    private func acceptLoop() {
        while true {
            let client = accept(listenFD, nil, nil)
            if client < 0 { break }
            Thread.detachNewThread { [weak self] in
                self?.serve(client)
            }
        }
    }

    private func serve(_ client: Int32) {
        defer { close(client) }
        var yes: Int32 = 1
        setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout.size(ofValue: yes)))
        var timeout = timeval(tv_sec: 2, tv_usec: 0)
        setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
        guard let request = readRequest(client) else { return }
        let path = request.target.split(separator: "?", maxSplits: 1).first.map(String.init) ?? request.target
        lock.lock()
        recordedTargets.append(path)
        let isSettings = path == "/api/settings"
        if isSettings { settingsRequestCount += 1 }
        let shouldHold = isSettings && hold
        if shouldHold { hold = false }
        let snapshot = storedBody
        let status = isSettings ? storedStatus : 404
        let waiter = self.waiter
        lock.unlock()
        if shouldHold { waiter?.wait() }
        write(status: status, body: isSettings ? snapshot : "{}", to: client)
        if isSettings {
            lock.lock()
            settingsServedCount += 1
            lock.unlock()
        }
    }

    private func readRequest(_ fd: Int32) -> (method: String, target: String)? {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while data.range(of: Data("\r\n\r\n".utf8)) == nil {
            let count = buffer.withUnsafeMutableBytes { raw in
                recv(fd, raw.baseAddress!, raw.count, 0)
            }
            if count <= 0 { return nil }
            data.append(contentsOf: buffer.prefix(count))
            if data.count > 1024 * 1024 { return nil }
        }
        guard let headerEnd = data.range(of: Data("\r\n\r\n".utf8)),
              let headerText = String(data: data.subdata(in: 0..<headerEnd.lowerBound), encoding: .utf8) else {
            return nil
        }
        let parts = headerText.components(separatedBy: "\r\n").first?.split(separator: " ").map(String.init) ?? []
        guard parts.count >= 2 else { return nil }
        return (parts[0], parts[1])
    }

    private func write(status: Int, body: String, to fd: Int32) {
        let reason = status == 200 ? "OK" : "Status"
        let text = "HTTP/1.1 \(status) \(reason)\r\nContent-Type: application/json\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        let payload = Array(text.utf8)
        var sent = 0
        while sent < payload.count {
            let count = payload.withUnsafeBytes { raw in
                send(fd, raw.baseAddress!.advanced(by: sent), payload.count - sent, 0)
            }
            if count <= 0 { break }
            sent += count
        }
    }
}
