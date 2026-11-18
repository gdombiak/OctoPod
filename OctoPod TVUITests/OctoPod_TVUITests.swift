//
//  OctoPod_TVUITests.swift
//  OctoPod TVUITests
//
//  Created by Gaston Dombiak on 2/21/20.
//  Copyright © 2020 Gaston Dombiak. All rights reserved.
//

import XCTest

class OctoPod_TVUITests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testPrintersScreenAppearsOnLaunchAndResume() {
        let app = XCUIApplication()
        app.launch()

        let printersScreen = app.staticTexts["Printers"].firstMatch
        XCTAssertTrue(printersScreen.waitForExistence(timeout: 10))

        XCUIRemote.shared.press(.menu)
        let appEnteredBackground = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                let state = app.state
                return state == .runningBackground || state == .runningBackgroundSuspended
            },
            object: nil
        )
        wait(for: [appEnteredBackground], timeout: 10)

        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(printersScreen.waitForExistence(timeout: 10))
    }

    func testTimeToFilamentOverflowKeepsJobAndCameraControlsOnScreen() {
        let app = XCUIApplication()
        app.launchArguments.append("--test-countdown-overflow")
        app.launch()

        let cancel = app.buttons.containing(.staticText, identifier: "Cancel").firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 8))
        XCTAssertTrue(app.frame.contains(cancel.frame), "Cancel must be on screen with wrapping countdown rows")
        XCTAssertTrue(app.frame.contains(app.staticTexts["Print Completion"].frame))

        let expand = app.buttons["expandCamera"]
        let remote = XCUIRemote.shared
        XCTAssertTrue(app.frame.contains(expand.frame))
        let lastCountdown = app.descendants(matching: .any).matching(identifier: "countdown-8").firstMatch
        for _ in 0..<8 where !lastCountdown.exists || !lastCountdown.hasFocus {
            remote.press(.down)
        }
        XCTAssertTrue(lastCountdown.exists && lastCountdown.hasFocus, app.debugDescription)
        XCTAssertTrue(app.scrollViews["countdownScroll"].frame.intersects(lastCountdown.frame))

        for direction in [XCUIRemote.Button.down, .right, .right, .right] where !expand.hasFocus {
            remote.press(direction)
        }
        XCTAssertTrue(expand.hasFocus, app.debugDescription)
        remote.press(.select)
        let restore = app.buttons["restoreCamera"]
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        XCTAssertTrue(app.frame.contains(restore.frame))
        XCTAssertTrue(app.frame.contains(app.staticTexts["Print Completion"].frame))
    }

    func testLaunchPerformance() {
        measure(metrics: [XCTOSSignpostMetric.applicationLaunch]) {
            XCUIApplication().launch()
        }
    }
}
