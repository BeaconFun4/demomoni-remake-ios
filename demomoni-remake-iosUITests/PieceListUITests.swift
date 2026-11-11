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

        app.tabButton("いちらん").tap()
        XCTAssertTrue(app.navigationBars["いちらん"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["ピース No.14 元町公園"].exists)
        XCTAssertFalse(app.buttons["ピース No.1 函館山"].exists)
    }

    /// 獲得したピースだけが盤に出る
    @MainActor
    func testShowsCollectedPieces() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-collectedPieceIDs", "0"]
        app.launch()

        app.tabButton("いちらん").tap()
        XCTAssertTrue(app.buttons["ピース No.14 元町公園"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["ピース No.1 函館山"].exists)
    }

    /// 盤の上に、ゲットしたピースの数と全部の数を出す
    @MainActor
    func testShowsPieceCount() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-collectedPieceIDs", "1,14,20"]
        app.launch()

        app.tabButton("いちらん").tap()
        // 文字（3 / 32）は読み上げのラベルに置き換わるので、ラベルで確かめる
        XCTAssertTrue(app.staticTexts["ゲットしたピース 3 こ、全部で 32 こ"].waitForExistence(timeout: 10))
    }

    /// 何も獲得していなければ 0 / 全部
    @MainActor
    func testShowsZeroPieceCount() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        app.tabButton("いちらん").tap()
        XCTAssertTrue(app.staticTexts["ゲットしたピース 0 こ、全部で 32 こ"].waitForExistence(timeout: 10))
    }
}
