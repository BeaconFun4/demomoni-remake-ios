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

    /// 何も獲得していなければ、一覧に印は付かず、詳細に答えは出ない
    @MainActor
    func testAnswerIsHiddenBeforeCollectingPiece() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        app.tabButton("なぞなぞ").tap()
        let riddle = app.buttons["函館ののっぽ"]
        XCTAssertTrue(riddle.waitForExistence(timeout: 5))
        XCTAssertNotEqual(riddle.value as? String, "ゲットずみ")

        riddle.tap()
        XCTAssertTrue(app.staticTexts["函館の白くて高いものといえば？"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["こたえ、五稜郭タワー"].exists)
    }

    /// 答えの場所のピース（五稜郭タワー）を獲得したなぞなぞだけ、一覧に印が付き、詳細に答えが出る
    @MainActor
    func testAnswerIsShownAfterCollectingPiece() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-collectedPieceIDs", "2"]
        app.launch()

        app.tabButton("なぞなぞ").tap()
        let solved = app.buttons["函館ののっぽ"]
        XCTAssertTrue(solved.waitForExistence(timeout: 5))
        XCTAssertEqual(solved.value as? String, "ゲットずみ")
        XCTAssertNotEqual(app.buttons["函館の見晴らし台"].value as? String, "ゲットずみ")

        solved.tap()
        XCTAssertTrue(app.staticTexts["こたえ、五稜郭タワー"].waitForExistence(timeout: 5))
        // ヒントは今までどおり出せる
        XCTAssertTrue(app.buttons["ヒントをみる"].exists)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["函館の見晴らし台"].tap()
        XCTAssertTrue(app.staticTexts["函館で夜景が綺麗な有名なところといえば？"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["こたえ、函館山"].exists)
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
