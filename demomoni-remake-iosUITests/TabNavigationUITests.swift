//
//  TabNavigationUITests.swift
//  demomoni-remake-iosUITests
//

import XCTest

final class TabNavigationUITests: XCTestCase {
    override func setUpWithError() throws {
        // UI テストでは失敗した時点で即座に止める
        continueAfterFailure = false
    }

    /// 起動すると 2 番目のタブ（さがす）が選ばれている
    @MainActor
    func testLaunchSelectsSearchTab() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["さがす画面"].waitForExistence(timeout: 5))
    }

    /// タブを押すと、その画面に切り替わる
    @MainActor
    func testTabsSwitchScreens() throws {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["なぞなぞ"].tap()
        XCTAssertTrue(app.staticTexts["なぞなぞ画面"].waitForExistence(timeout: 5))

        app.tabBars.buttons["いちらん"].tap()
        XCTAssertTrue(app.staticTexts["いちらん画面"].waitForExistence(timeout: 5))
    }
}
