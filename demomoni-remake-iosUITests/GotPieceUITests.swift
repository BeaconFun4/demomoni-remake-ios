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

    /// 擬似検知でビーコンを見つけると「ピースをゲットしたよ！！」画面が出て、閉じた後はもう出ない
    @MainActor
    func testDetectedPieceIsShownOnce() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-fakeBeaconID", "0"]
        app.launch()

        // 擬似検知は探し始めてから 2 秒後に見つける
        let title = app.staticTexts["ピースをゲットしたよ！！"]
        XCTAssertTrue(title.waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["元町公園"].exists)
        XCTAssertTrue(app.staticTexts["検知場所、元町・函館山"].exists)

        app.buttons["とじる"].tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 5))

        // さがすタブに戻ると探し直すが、獲得済みなのでもう出ない
        XCTAssertTrue(app.staticTexts["まちをあるいてみよう！！"].waitForExistence(timeout: 5))
        XCTAssertFalse(title.waitForExistence(timeout: 5))
    }
}
