//
//  RiddleUITests.swift
//  demomoni-remake-iosUITests
//

import XCTest

/// 一覧の 1 問目（答えは五稜郭タワー）と 2 問目（答えは函館山）のタイトル・問題文。`riddles.json` と同じ文
private enum RiddleText {
    static let firstTitle = "昼間の星"
    static let firstContent = "昼間なのに、星が見えるタワーがあるんだって。でも、空を見上げても見えないよ。なーんだ？"
    static let secondTitle = "山なのに入れもの？"
    static let secondContent = """
        手紙をポストに入れることを「投□（とうかん）」というよ。ポストは手紙の入れもの。\
        この□の字を名前の1文字めに使った山があるんだって。山なのに入れもの……？ \
        わけは、答えの名前を見て、ふもとの街を思いうかべるとわかるよ。
        """
}

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
        app.buttons[RiddleText.firstTitle].tap()

        XCTAssertTrue(app.staticTexts[RiddleText.firstContent].waitForExistence(timeout: 5))
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
        let riddle = app.buttons[RiddleText.firstTitle]
        XCTAssertTrue(riddle.waitForExistence(timeout: 5))
        XCTAssertNotEqual(riddle.value as? String, "ゲットずみ")

        riddle.tap()
        XCTAssertTrue(app.staticTexts[RiddleText.firstContent].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["こたえ、五稜郭タワー"].exists)
    }

    /// 答えの場所のピース（五稜郭タワー）を獲得したなぞなぞだけ、一覧に印が付き、詳細に答えが出る
    @MainActor
    func testAnswerIsShownAfterCollectingPiece() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-collectedPieceIDs", "2"]
        app.launch()

        app.tabButton("なぞなぞ").tap()
        let solved = app.buttons[RiddleText.firstTitle]
        XCTAssertTrue(solved.waitForExistence(timeout: 5))
        XCTAssertEqual(solved.value as? String, "ゲットずみ")
        XCTAssertNotEqual(app.buttons[RiddleText.secondTitle].value as? String, "ゲットずみ")

        solved.tap()
        XCTAssertTrue(app.staticTexts["こたえ、五稜郭タワー"].waitForExistence(timeout: 5))
        // ヒントは今までどおり出せる
        XCTAssertTrue(app.buttons["ヒントをみる"].exists)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons[RiddleText.secondTitle].tap()
        XCTAssertTrue(app.staticTexts[RiddleText.secondContent].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["こたえ、函館山"].exists)
    }

    /// 詳細から戻ると一覧に戻り、別のなぞなぞではヒントが隠れている
    @MainActor
    func testHintIsHiddenForAnotherRiddle() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        app.tabButton("なぞなぞ").tap()
        app.buttons[RiddleText.firstTitle].tap()
        app.buttons["ヒントをみる"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons[RiddleText.secondTitle].tap()
        XCTAssertTrue(app.staticTexts[RiddleText.secondContent].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["ヒントをみる"].exists)
    }
}
