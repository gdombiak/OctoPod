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

    func testLaunchPerformance() {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTOSSignpostMetric.applicationLaunch]) {
                XCUIApplication().launch()
            }
        }
    }
}
