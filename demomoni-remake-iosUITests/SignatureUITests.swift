//
//  SignatureUITests.swift
//  demomoni-remake-iosUITests
//

import XCTest

final class SignatureUITests: XCTestCase {
    override func setUpWithError() throws {
        // UI テストでは失敗した時点で即座に止める
        continueAfterFailure = false
    }

    /// 獲得したピースの詳細を開き、「サインをかく！」でサインの画面を開く
    @MainActor
    private func openSignature(_ app: XCUIApplication) {
        app.launchArguments = ["-uiTesting", "-collectedPieceIDs", "0"]
        app.launch()

        app.tabButton("いちらん").tap()
        let piece = app.buttons["ピース No.14 元町公園"]
        XCTAssertTrue(piece.waitForExistence(timeout: 10))
        piece.tap()
        let signButton = app.buttons["サインをかく！"]
        XCTAssertTrue(signButton.waitForExistence(timeout: 10))
        signButton.tap()
        XCTAssertTrue(app.buttons["これでかんせい！"].waitForExistence(timeout: 10))
    }

    /// サインを描いて「これでかんせい！」を押すと、詳細のピースにサインが重なる
    @MainActor
    func testDrawAndSaveSignature() throws {
        let app = XCUIApplication()
        openSignature(app)

        for tool in ["ぺん", "けしごむ", "ぜんぶけす！", "もどる！"] {
            XCTAssertTrue(app.buttons[tool].exists, "\(tool) のボタン")
        }
        let canvas = app.descendants(matching: .any)["サインをかくところ"].firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3))
            .press(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.7)))

        app.buttons["これでかんせい！"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["サインをかいたピースの画像"].waitForExistence(timeout: 10))
    }

    /// 「ピースがめんにもどる」では保存せずに閉じる
    @MainActor
    func testBackWithoutSaving() throws {
        let app = XCUIApplication()
        openSignature(app)

        let canvas = app.descendants(matching: .any)["サインをかくところ"].firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3))
            .press(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.7)))

        app.buttons["ピースがめんにもどる"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["ピースの画像"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["サインをかいたピースの画像"].exists)
    }

    /// 描いた線を「もどる！」で取り消して保存すると、サインは残らない
    @MainActor
    func testUndoThenSaveLeavesNoSignature() throws {
        let app = XCUIApplication()
        openSignature(app)

        let canvas = app.descendants(matching: .any)["サインをかくところ"].firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3))
            .press(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.7)))
        app.buttons["もどる！"].tap()

        app.buttons["これでかんせい！"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["ピースの画像"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["サインをかいたピースの画像"].waitForExistence(timeout: 3))
    }
}
