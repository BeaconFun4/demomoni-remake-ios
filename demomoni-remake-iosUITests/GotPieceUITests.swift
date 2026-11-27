//
//  GotPieceUITests.swift
//  demomoni-remake-iosUITests
//

import XCTest

final class GotPieceUITests: XCTestCase {
    override func setUpWithError() throws {
        // UI テストでは失敗した時点で即座に止める
        continueAfterFailure = false
    }

    /// 擬似検知でピースの場所に来ると「ピースをゲットしたよ！！」画面が出て、閉じた後はもう出ない。
    /// 函館山は、ほかのピースの範囲（半径 100 m）と重ならない
    @MainActor
    func testDetectedPieceIsShownOnce() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-fakePieceID", "1"]
        app.launch()

        // 擬似検知は調べ始めてから 2 秒後に、函館山の場所にいることにする
        let title = app.staticTexts["ピースをゲットしたよ！！"]
        XCTAssertTrue(title.waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["函館山"].exists)
        XCTAssertTrue(app.staticTexts["検知場所、元町・函館山"].exists)

        app.buttons["とじる"].tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 5))

        // タブを行き来してさがすタブに戻ると調べ直すが、獲得済みなのでもう出ない
        XCTAssertTrue(app.staticTexts["まちをあるいてみよう！！"].waitForExistence(timeout: 5))
        app.tabButton("いちらん").tap()
        app.tabButton("さがす").tap()
        XCTAssertTrue(app.staticTexts["まちをあるいてみよう！！"].waitForExistence(timeout: 5))
        XCTAssertFalse(title.waitForExistence(timeout: 10))
    }
}
