//
//  RiddleUITests.swift
//  demomoni-remake-iosUITests
//

import XCTest

final class RiddleUITests: XCTestCase {
    override func setUpWithError() throws {
        // UI テストでは失敗した時点で即座に止める
        continueAfterFailure = false
    }

    /// なぞなぞを押すと詳細で問題文が出て、「ヒントをみる」でヒントが出る
    @MainActor
    func testOpenRiddleAndShowHint() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        app.tabButton("なぞなぞ").tap()
        app.buttons["函館ののっぽ"].tap()

        XCTAssertTrue(app.staticTexts["函館の白くて高いものといえば？"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["ヒント、五◯郭タワー"].exists)

        app.buttons["ヒントをみる"].tap()
        XCTAssertTrue(app.staticTexts["ヒント、五◯郭タワー"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["ヒントをみる"].exists)
    }

    /// 詳細から戻ると一覧に戻り、別のなぞなぞではヒントが隠れている
    @MainActor
    func testHintIsHiddenForAnotherRiddle() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        app.tabButton("なぞなぞ").tap()
        app.buttons["函館ののっぽ"].tap()
        app.buttons["ヒントをみる"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["函館の見晴らし台"].tap()
        XCTAssertTrue(app.staticTexts["函館で夜景が綺麗な有名なところといえば？"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["ヒントをみる"].exists)
    }
}
