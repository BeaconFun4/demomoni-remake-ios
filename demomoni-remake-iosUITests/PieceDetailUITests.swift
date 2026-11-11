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

    /// Debug 構成だけ、詳細の「編集」から外すと盤へ戻り、盤からそのピースが消える。
    /// UI テストは Debug 構成のアプリで動くので、編集の操作が出る
    @MainActor
    func testRemovePieceFromDetail() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-collectedPieceIDs", "0"]
        app.launch()

        app.tabButton("いちらん").tap()
        let piece = app.buttons["ピース No.14 元町公園"]
        XCTAssertTrue(piece.waitForExistence(timeout: 10), "獲得したピースのボタン")
        piece.tap()
        XCTAssertTrue(app.staticTexts["ピース No.14"].waitForExistence(timeout: 10), "ピース詳細")

        let edit = app.buttons["編集"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5), "編集のメニュー")
        edit.tap()
        let remove = app.buttons["外す"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5), "外すの操作")
        remove.tap()

        // 盤へ戻り、ピースは空きマスに戻る
        XCTAssertTrue(app.staticTexts["ゲットしたピース 0 こ、全部で 32 こ"].waitForExistence(timeout: 10), "外した後の数")
        XCTAssertTrue(app.buttons["ピース No.14 元町公園 を埋める"].waitForExistence(timeout: 5), "空きマス No.14 のボタン")
        XCTAssertFalse(piece.exists)
    }

    /// Debug 構成だけ、詳細の「編集」に日時を変える・サインを消す・外すが出る。
    /// サインが無ければ「サインを消す」は押せない。「日時を変える」はシートで日時を選ぶ
    @MainActor
    func testEditMenuItems() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-collectedPieceIDs", "0"]
        app.launch()

        app.tabButton("いちらん").tap()
        let piece = app.buttons["ピース No.14 元町公園"]
        XCTAssertTrue(piece.waitForExistence(timeout: 10), "獲得したピースのボタン")
        piece.tap()

        let edit = app.buttons["編集"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10), "編集のメニュー")
        edit.tap()
        XCTAssertTrue(app.buttons["外す"].waitForExistence(timeout: 5), "外すの操作")
        XCTAssertFalse(app.buttons["サインを消す"].isEnabled, "サインが無いときのサインを消す")
        let changeDate = app.buttons["日時を変える"]
        XCTAssertTrue(changeDate.exists, "日時を変えるの操作")
        changeDate.tap()

        XCTAssertTrue(app.navigationBars["日時を変える"].waitForExistence(timeout: 5), "日時を変えるシート")
        app.buttons["保存"].tap()
        XCTAssertTrue(app.navigationBars["日時を変える"].waitForNonExistence(timeout: 5), "保存したらシートを閉じる")
        XCTAssertTrue(app.staticTexts["ピース No.14"].exists, "ピース詳細に戻る")
    }
}
