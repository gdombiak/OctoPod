import XCTest

final class WatchInterfaceModelTests: XCTestCase {

    func testInitialPageUsesPanelWhenPrintersExist() {
        XCTAssertEqual(WatchPage.initial(printerCount: 0), .printers)
        XCTAssertEqual(WatchPage.initial(printerCount: 2), .panel)
    }

    func testPrintersSortByPositionThenNameAndHideRefreshWhenEmpty() {
        let printers: [[String: Any]] = [
            printer(name: "Zulu", position: 1, isDefault: false),
            printer(name: "Mike", position: nil, isDefault: false),
            printer(name: "Alpha", position: 1, isDefault: true),
            printer(name: "Bravo", position: 2, isDefault: false)
        ]

        let state = WatchPrinterList.state(for: printers)

        XCTAssertEqual(state.rows.map(\.name), ["Mike", "Alpha", "Zulu", "Bravo"])
        XCTAssertEqual(state.rows.map(\.isDefault), [false, true, false, false])
        XCTAssertFalse(state.showsSyncPrompt)
        XCTAssertTrue(state.showsRefresh)

        let empty = WatchPrinterList.state(for: [])
        XCTAssertTrue(empty.rows.isEmpty)
        XCTAssertTrue(empty.showsSyncPrompt)
        XCTAssertFalse(empty.showsRefresh)
    }

    func testPanelPrintingPausedAndOperationalButtons() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        var panel = WatchPanelState()
        panel.apply(panelInfo: printingPayload(printer: "printing", completion: 12.34, secondsLeft: 3661), screenWidth: 200, calendar: calendar)

        XCTAssertFalse(panel.showsError)
        XCTAssertEqual(panel.stateText, "Printing")
        XCTAssertEqual(panel.completionText, "12.3%")
        XCTAssertEqual(panel.timeLeftText, "About 1h 1m")
        XCTAssertEqual(panel.bedTempText, "60.0 C")
        XCTAssertEqual(panel.tool0Text, "210.5 C")
        XCTAssertTrue(panel.jobButtons.showsGroup)
        XCTAssertFalse(panel.jobButtons.showsResume)
        XCTAssertTrue(panel.jobButtons.showsPause)
        XCTAssertTrue(panel.jobButtons.showsCancel)

        panel.apply(panelInfo: ["printer": "paused", "state": "Paused"])
        XCTAssertTrue(panel.jobButtons.showsResume)
        XCTAssertFalse(panel.jobButtons.showsPause)
        XCTAssertTrue(panel.jobButtons.showsCancel)
        XCTAssertEqual(panel.completionText, "12.3%")

        panel.apply(panelInfo: ["printer": "operational", "state": "Operational"])
        XCTAssertEqual(panel.jobButtons, .hidden)
        XCTAssertNil(panel.completionText)
        XCTAssertNil(panel.timeLeftText)
        XCTAssertNil(panel.etaText)
    }

    func testPanelKeepsJobButtonsForIntermediatePrinterStates() {
        var panel = WatchPanelState()
        panel.apply(panelInfo: ["printer": "printing"])
        panel.apply(panelInfo: ["printer": "pausing", "state": "Pausing"])

        XCTAssertTrue(panel.jobButtons.showsGroup)
        XCTAssertFalse(panel.jobButtons.showsResume)
        XCTAssertTrue(panel.jobButtons.showsPause)
        XCTAssertTrue(panel.jobButtons.showsCancel)

        panel.apply(panelInfo: ["printer": "operational"])
        panel.apply(panelInfo: ["printer": "cancelling", "completion": 4.0])

        XCTAssertTrue(panel.jobButtons.showsGroup)
        XCTAssertFalse(panel.jobButtons.showsResume)
        XCTAssertFalse(panel.jobButtons.showsPause)
        XCTAssertFalse(panel.jobButtons.showsCancel)
        XCTAssertEqual(panel.completionText, "4.0%")
    }

    func testPanelErrorClearsFieldsAndCanStillShowPalette() {
        var panel = WatchPanelState()
        panel.apply(panelInfo: printingPayload(printer: "printing", completion: 10, secondsLeft: 60))
        panel.apply(panelInfo: [
            "error": "Connection failed",
            "palette2LastPing": "1s",
            "palette2LastVariation": "0.2",
            "palette2MaxVariation": "1.0"
        ])

        XCTAssertTrue(panel.showsError)
        XCTAssertEqual(panel.errorText, "Connection failed")
        XCTAssertNil(panel.stateText)
        XCTAssertNil(panel.completionText)
        XCTAssertEqual(panel.bedTempText, "    ")
        XCTAssertEqual(panel.tool0Text, "     ")
        XCTAssertFalse(panel.row1.visible)
        XCTAssertFalse(panel.row1.leading.enabled)
        XCTAssertEqual(panel.jobButtons, .hidden)
        XCTAssertTrue(panel.showsPalette2)
        XCTAssertEqual(panel.palette2LastPing, "1s")
        XCTAssertEqual(panel.palette2LastVariance, "0.2")
    }

    func testPanelToolRowsStayPutWhenTool0IsMissingAndOfflineStateIsShortened() {
        var panel = WatchPanelState()
        panel.apply(panelInfo: [
            "tool0Temp": 200.0,
            "tool1Temp": 201.0,
            "chamberTemp": 40.0,
            "tool2Temp": 202.0,
            "tool4Temp": 204.0,
            "state": "Offline (Error: timeout)"
        ])

        XCTAssertEqual(panel.stateText, "Offline")
        XCTAssertTrue(panel.row1.visible)
        XCTAssertEqual(panel.row1.leading.text, "201.0 C")
        XCTAssertTrue(panel.row1.leading.enabled)
        XCTAssertEqual(panel.row1.trailing.text, "40.0 C")
        XCTAssertTrue(panel.row1.trailing.enabled)
        XCTAssertTrue(panel.row2.visible)
        XCTAssertEqual(panel.row2.leading.text, "202.0 C")
        XCTAssertFalse(panel.row2.trailing.enabled)
        XCTAssertTrue(panel.row3.visible)
        XCTAssertEqual(panel.row3.leading.text, "204.0 C")

        panel.apply(panelInfo: ["state": "Printing", "bedTemp": 55.0])
        XCTAssertEqual(panel.tool0Text, "200.0 C")
        XCTAssertEqual(panel.row1.leading.text, "201.0 C")
        XCTAssertTrue(panel.row1.visible)
        XCTAssertEqual(panel.bedTempText, "55.0 C")
    }

    func testPanelStringTimeLeftAndClearFields() {
        var panel = WatchPanelState()
        panel.apply(panelInfo: ["printTimeLeft": "soon", "printer": "printing"])
        XCTAssertEqual(panel.timeLeftText, "soon")
        XCTAssertNil(panel.etaText)

        panel.clearFields()
        XCTAssertNil(panel.stateText)
        XCTAssertNil(panel.bedTempText)
        XCTAssertEqual(panel.tool0Text, "     ")
        XCTAssertEqual(panel.row1.leading.text, "     ")
        XCTAssertTrue(panel.jobButtons.showsPause)
    }

    func testPanelHidesButtonsWhenPrinterValueIsMissing() {
        var panel = WatchPanelState()
        panel.apply(panelInfo: ["printer": "printing"])
        panel.apply(panelInfo: ["state": "Offline"])
        XCTAssertEqual(panel.jobButtons, .hidden)
        XCTAssertEqual(panel.stateText, "Offline")
    }

    func testPanelCacheIsFreshForUnderTenWholeSeconds() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertTrue(WatchPanelCache.isFresh(lastRefresh: start, now: start.addingTimeInterval(9.9)))
        XCTAssertFalse(WatchPanelCache.isFresh(lastRefresh: start, now: start.addingTimeInterval(10)))
    }

    func testCameraPagingClampsAndChoosesDirectOrHLSFallback() {
        XCTAssertEqual(WatchCameraPage.controls(count: 0, index: 3), WatchCameraPage.empty)
        XCTAssertEqual(
            WatchCameraPage.controls(count: 1, index: 0),
            WatchCameraControls(index: 0, showsPrevious: false, showsNext: false, showsImage: true, cameraId: "0")
        )
        XCTAssertEqual(
            WatchCameraPage.controls(count: 3, index: 1),
            WatchCameraControls(index: 1, showsPrevious: true, showsNext: true, showsImage: true, cameraId: "1")
        )
        XCTAssertEqual(WatchCameraPage.controls(count: 2, index: 5).index, 0)
        XCTAssertEqual(WatchCameraPage.controls(count: 3, index: 2).showsNext, false)

        XCTAssertEqual(WatchCameraPage.fallback(for: "http://printer/cam.m3u8"), .unsupportedHLS)
        XCTAssertEqual(WatchCameraPage.fallback(for: "http://printer/cam.jpg"), .direct)
        XCTAssertFalse(WatchTimeFormatting.isHLS(url: "http://printer/stream"))
    }

    func testPanelRefreshesWhenSceneReturnsToActiveAndSkipsLaunchAndPageSelection() {
        // PanelScreen.handleAppear / handleScene call this before activate().
        var panel = WatchPanelLifecycle()

        // Launch refreshes from appearance. The initial active scene is that same launch.
        XCTAssertTrue(panel.appear())
        XCTAssertFalse(panel.sceneChanged(to: .active, panelSelected: true))
        XCTAssertFalse(panel.sceneChanged(to: .active, panelSelected: true))

        // onChange does not emit the phase already in effect, so background can be the first scene event.
        XCTAssertFalse(panel.sceneChanged(to: .background, panelSelected: true))
        XCTAssertTrue(panel.sceneChanged(to: .active, panelSelected: true))
        XCTAssertFalse(panel.sceneChanged(to: .inactive, panelSelected: true))
        XCTAssertTrue(panel.sceneChanged(to: .active, panelSelected: true))

        // Coming forward on another page does not refresh Panel. Selecting Panel is appearance only.
        XCTAssertFalse(panel.sceneChanged(to: .background, panelSelected: false))
        XCTAssertFalse(panel.sceneChanged(to: .active, panelSelected: false))
        XCTAssertTrue(panel.appear())
        XCTAssertFalse(panel.sceneChanged(to: .active, panelSelected: true))

        // An active event that arrives before the page has appeared is not a refresh.
        var early = WatchPanelLifecycle()
        XCTAssertFalse(early.sceneChanged(to: .active, panelSelected: true))
        XCTAssertTrue(early.appear())
        XCTAssertFalse(early.sceneChanged(to: .active, panelSelected: true))
        XCTAssertFalse(early.sceneChanged(to: .background, panelSelected: true))
        XCTAssertTrue(early.sceneChanged(to: .active, panelSelected: true))
    }

    func testPhoneFileMatchesTokenBeforeAcknowledgment() {
        // CamerasScreen.imageReceived calls matches before it changes the image, error, or refresh state.
        // The iPhone echoes cameraId unchanged, so the file can arrive before the reply.
        var phone = WatchCameraPhoneSession()
        phone.start(token: "token-a")
        XCTAssertTrue(phone.matches("token-a"))
        XCTAssertFalse(phone.matches("0"))

        phone.start(token: "token-b")
        XCTAssertFalse(phone.matches("token-a"))
        XCTAssertTrue(phone.matches("token-b"))

        // A → B → A and a printer that reuses camera index 0 each get a new token.
        phone.start(token: "token-a2")
        XCTAssertTrue(phone.matches("token-a2"))
        XCTAssertFalse(phone.matches("token-a"))
        XCTAssertFalse(phone.matches("token-b"))
        phone.start(token: "token-printer")
        XCTAssertTrue(phone.matches("token-printer"))
        XCTAssertFalse(phone.matches("token-a2"))
    }

    func testSameCameraRefreshRejectsThePreviousPhoneFile() {
        var phone = WatchCameraPhoneSession()
        phone.start(token: "refresh-1")
        XCTAssertTrue(phone.matches("refresh-1"))
        phone.start(token: "refresh-2")
        XCTAssertFalse(phone.matches("refresh-1"))
        XCTAssertTrue(phone.matches("refresh-2"))

        // Direct playback cancels the phone request, so its file cannot update that stream.
        phone.cancel("refresh-2")
        XCTAssertFalse(phone.matches("refresh-2"))
        phone.cancel("refresh-1")
        XCTAssertNil(phone.token)
    }

    func testFileReadErrorKeepsTheCurrentTokenAndIgnoresAStaleOne() {
        // PrinterManager.fileReceived uses this before it changes the image.
        let current = WatchCameraFile.event(metadata: ["cameraId": "refresh-2"], readFailed: true)
        let stale = WatchCameraFile.event(metadata: ["cameraId": "refresh-1"], readFailed: true)
        let legacyIndex = WatchCameraFile.event(metadata: ["cameraId": "0"], readFailed: false)
        let missing = WatchCameraFile.event(metadata: nil, readFailed: true)
        let notAString = WatchCameraFile.event(metadata: ["cameraId": 0], readFailed: true)

        XCTAssertEqual(current, .deliver(token: "refresh-2", failed: true))
        XCTAssertEqual(stale, .deliver(token: "refresh-1", failed: true))
        XCTAssertEqual(legacyIndex, .deliver(token: "0", failed: false))
        XCTAssertEqual(missing, .ignored)
        XCTAssertEqual(notAString, .ignored)

        var phone = WatchCameraPhoneSession()
        phone.start(token: "refresh-2")
        guard case let .deliver(currentToken, currentFailed) = current,
              case let .deliver(staleToken, staleFailed) = stale else {
            return XCTFail("Expected both read errors to keep their tokens")
        }
        XCTAssertTrue(currentFailed)
        XCTAssertTrue(staleFailed)
        XCTAssertTrue(phone.matches(currentToken))
        XCTAssertFalse(phone.matches(staleToken))
    }

    func testLateCameraCallbackCannotUpdateOrStopANewerStream() {
        var playback = WatchCameraPlayback()
        let cameraA = playback.token
        playback.invalidate()
        let cameraB = playback.token

        XCTAssertNotEqual(cameraA, cameraB)
        XCTAssertFalse(playback.isCurrent(cameraA))
        XCTAssertTrue(playback.isCurrent(cameraB))
        XCTAssertFalse(WatchCameraPage.isSelected("0", selectedCameraId: "1"))
        XCTAssertTrue(WatchCameraPage.isSelected("1", selectedCameraId: "1"))
    }

    func testTimeLeftOmitsMinutesOnlyForLongDurationsOn38mmAndETAUsesTheInjectedClock() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertEqual(WatchTimeFormatting.timeLeft(seconds: 0, includeMinutes: true, calendar: calendar), "")
        XCTAssertEqual(WatchTimeFormatting.timeLeft(seconds: -4, includeMinutes: true, calendar: calendar), "Unknown")
        XCTAssertEqual(WatchTimeFormatting.timeLeft(seconds: 90061, includeMinutes: true, calendar: calendar), "About 1d 1h 1m")
        XCTAssertEqual(WatchTimeFormatting.timeLeft(seconds: 90061, includeMinutes: false, calendar: calendar), "About 1d 1h")
        XCTAssertFalse(WatchTimeFormatting.includeMinutes(screenWidth: 136, seconds: 90061))
        XCTAssertTrue(WatchTimeFormatting.includeMinutes(screenWidth: 136, seconds: 3600))
        XCTAssertTrue(WatchTimeFormatting.includeMinutes(screenWidth: 184, seconds: 90061))

        XCTAssertEqual(WatchTimeFormatting.eta(seconds: 0, now: now, calendar: calendar), "")
        XCTAssertEqual(WatchTimeFormatting.eta(seconds: -1, now: now, calendar: calendar), "Unknown")
        XCTAssertEqual(WatchTimeFormatting.eta(seconds: 3600, now: now, calendar: calendar), "11:13\u{202F}PM")
        XCTAssertEqual(WatchTimeFormatting.eta(seconds: 7200, now: now, calendar: calendar), "11/15/23, 12:13\u{202F}AM")
    }

    private func printer(name: String, position: Int16?, isDefault: Bool) -> [String: Any] {
        var printer: [String: Any] = ["name": name, "isDefault": isDefault]
        if let position = position {
            printer["position"] = position
        }
        return printer
    }

    private func printingPayload(printer: String, completion: Double, secondsLeft: Int) -> [String: Any] {
        [
            "printer": printer,
            "state": "Printing",
            "completion": completion,
            "printTimeLeft": secondsLeft,
            "bedTemp": 60.0,
            "tool0Temp": 210.5
        ]
    }
}
