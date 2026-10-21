//
//  PieceDetailUITests.swift
//  demomoni-remake-iosUITests
//

import XCTest

final class PieceDetailUITests: XCTestCase {
    override func setUpWithError() throws {
        // UI テストでは失敗した時点で即座に止める
        continueAfterFailure = false
    }

    /// いちらんで獲得したピースを押すとピース詳細が開き、番号・エリア・場所と「サインをかく！」が出る
    @MainActor
    func testOpenPieceDetailFromList() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-collectedPieceIDs", "0"]
        app.launch()

        app.tabButton("いちらん").tap()
        let piece = app.buttons["ピース No.14 元町公園"]
        XCTAssertTrue(piece.waitForExistence(timeout: 10))
        piece.tap()

        XCTAssertTrue(app.staticTexts["ピース No.14"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["エリア:元町・函館山"].exists)
        XCTAssertTrue(app.staticTexts["ばしょ:元町公園"].exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "にちじ:")).firstMatch.exists)
        XCTAssertTrue(app.buttons["サインをかく！"].exists)

        // 戻るといちらんに戻る
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(piece.waitForExistence(timeout: 10))
    }
}
