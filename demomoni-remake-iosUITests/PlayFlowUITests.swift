//
//  PlayFlowUITests.swift
//  demomoni-remake-iosUITests
//

import XCTest

/// 検知からサインまでの、遊ぶ流れを通しで確かめる
final class PlayFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        // UI テストでは失敗した時点で即座に止める
        continueAfterFailure = false
    }

    /// 擬似検知 → ゲット画面 → いちらんにピースが出る → ピース詳細 → サインを描いて保存 → 詳細・いちらんにサインが出る
    @MainActor
    func testFromDetectionToSignature() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-fakeBeaconID", "0"]
        app.launch()

        // さがすタブで、擬似検知が 2 秒後に元町公園のビーコンを見つける
        let gotTitle = app.staticTexts["ピースをゲットしたよ！！"]
        XCTAssertTrue(gotTitle.waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["元町公園"].exists)
        app.buttons["とじる"].tap()
        XCTAssertTrue(gotTitle.waitForNonExistence(timeout: 10))

        // いちらんの盤に、獲得したピースだけが出る
        app.tabButton("いちらん").tap()
        let piece = app.buttons["ピース No.14 元町公園"]
        XCTAssertTrue(piece.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["ピース No.1 函館山"].exists)

        // ピース詳細
        piece.tap()
        XCTAssertTrue(app.staticTexts["ピース No.14"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["ばしょ:元町公園"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["ピースの画像"].exists)

        // サインの画面を開き、保存せずに閉じる
        app.buttons["サインをかく！"].tap()
        XCTAssertTrue(app.buttons["ピースがめんにもどる"].waitForExistence(timeout: 10))
        app.buttons["ピースがめんにもどる"].tap()
        XCTAssertTrue(app.staticTexts["ピース No.14"].waitForExistence(timeout: 10))

        // もう一度開いて描き、保存すると詳細のピースにサインが重なる
        app.buttons["サインをかく！"].tap()
        let canvas = app.descendants(matching: .any)["サインをかくところ"].firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 10))
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3))
            .press(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.7)))
        app.buttons["これでかんせい！"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["サインをかいたピースの画像"].waitForExistence(timeout: 10))

        // さがすタブに戻っても、獲得済みのピースのゲット画面はもう出ない
        app.tabButton("さがす").tap()
        XCTAssertTrue(app.staticTexts["まちをあるいてみよう！！"].waitForExistence(timeout: 10))
        XCTAssertFalse(gotTitle.waitForExistence(timeout: 8))
    }
}
