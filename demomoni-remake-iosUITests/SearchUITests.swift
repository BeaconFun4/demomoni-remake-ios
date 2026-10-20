//
//  SearchUITests.swift
//  demomoni-remake-iosUITests
//

import XCTest

final class SearchUITests: XCTestCase {
    override func setUpWithError() throws {
        // UI テストでは失敗した時点で即座に止める
        continueAfterFailure = false
    }

    /// さがすタブに元アプリの文言と、歩くうさぎ・道が出る
    @MainActor
    func testShowsWalkingRabbit() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        XCTAssertTrue(app.staticTexts["まちをあるいてみよう！！"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["道を歩くうさぎ"].exists || app.images["道を歩くうさぎ"].exists)
    }

    /// 「あそびかた」のボタンでチュートリアルが開き、「とじる」で閉じる
    @MainActor
    func testOpenAndCloseTutorial() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        app.buttons["あそびかた"].tap()
        let tutorial = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "ピースのありかがわかるよ！！")).firstMatch
        XCTAssertTrue(tutorial.waitForExistence(timeout: 5))
        XCTAssertTrue(tutorial.label.contains("ここをおしてなぞなぞをとくと"))

        app.buttons["とじる"].tap()
        XCTAssertTrue(tutorial.waitForNonExistence(timeout: 5))
    }
}
