//
//  PieceListUITests.swift
//  demomoni-remake-iosUITests
//

import XCTest

final class PieceListUITests: XCTestCase {
    override func setUpWithError() throws {
        // UI テストでは失敗した時点で即座に止める
        continueAfterFailure = false
    }

    /// 何も獲得していなければ、盤にピースは出ない
    @MainActor
    func testEmptyBoard() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        app.tabBars.buttons["いちらん"].tap()
        XCTAssertTrue(app.navigationBars["いちらん"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.images["ピース No.14 元町公園"].exists)
        XCTAssertFalse(app.images["ピース No.1 函館山"].exists)
    }

    /// 獲得したピースだけが盤に出る
    @MainActor
    func testShowsCollectedPieces() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-collectedPieceIDs", "0"]
        app.launch()

        app.tabBars.buttons["いちらん"].tap()
        XCTAssertTrue(app.images["ピース No.14 元町公園"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.images["ピース No.1 函館山"].exists)
    }
}
