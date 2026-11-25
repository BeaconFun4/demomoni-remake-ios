//
//  PiecePhotoUITests.swift
//  demomoni-remake-iosUITests
//

import XCTest

/// ピース詳細でピースをうらがえし、裏側の写真の上に手書きする
final class PiecePhotoUITests: XCTestCase {
    override func setUpWithError() throws {
        // UI テストでは失敗した時点で即座に止める
        continueAfterFailure = false
    }

    /// 獲得したピースのピース詳細を開く
    @MainActor
    private func openPieceDetail(_ app: XCUIApplication) {
        app.tabButton("いちらん").tap()
        let piece = app.buttons["ピース No.14 元町公園"]
        XCTAssertTrue(piece.waitForExistence(timeout: 10), "獲得したピースのボタン")
        piece.tap()
        XCTAssertTrue(app.staticTexts["ピース No.14"].waitForExistence(timeout: 10), "ピース詳細")
    }

    /// 写真が無いピースをうらがえすと、写真を入れる案内と「しゃしんをえらぶ」が出る。もう一度うらがえすと表に戻る。
    /// 「しゃしんをとる」はカメラを使える端末だけに出る（iOS 26 の Simulator は使える扱いになるので、ここでは確かめない）
    @MainActor
    func testFlipPieceWithoutPhoto() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-collectedPieceIDs", "0"]
        app.launch()
        openPieceDetail(app)

        let flip = app.buttons["うらがえす"]
        XCTAssertTrue(flip.waitForExistence(timeout: 5), "うらがえすのボタン")
        flip.tap()
        XCTAssertTrue(app.descendants(matching: .any)["ピースのうら、しゃしんはまだないよ"].waitForExistence(timeout: 5), "写真の無い裏側")
        XCTAssertTrue(app.buttons["しゃしんをえらぶ"].exists, "しゃしんをえらぶのボタン")
        XCTAssertFalse(app.buttons["サインをかく！"].exists, "裏側ではサインのボタンを出さない")

        flip.tap()
        XCTAssertTrue(app.buttons["サインをかく！"].waitForExistence(timeout: 5), "表に戻る")
        XCTAssertTrue(app.descendants(matching: .any)["ピースの画像"].exists, "表のピースの画像")
    }

    /// 写真を入れたピースの裏側で「かきこむ！」から描いて保存すると、写真に手書きが重なる。「しゃしんをけす」で確かめてから消す
    @MainActor
    func testDrawOnPhotoAndRemovePhoto() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-collectedPieceIDs", "0", "-samplePhotoPieceIDs", "0"]
        app.launch()
        openPieceDetail(app)

        app.buttons["うらがえす"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["ピースのうらのしゃしん"].waitForExistence(timeout: 5), "写真の入った裏側")

        app.buttons["かきこむ！"].tap()
        let canvas = app.descendants(matching: .any)["しゃしんにかきこむところ"].firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 10), "写真の上に描くところ")
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3))
            .press(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.7)))
        app.buttons["これでかんせい！"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["かきこんだピースのうらのしゃしん"].waitForExistence(timeout: 10),
            "手書きを重ねた写真"
        )

        app.buttons["しゃしんをけす"].tap()
        let alert = app.alerts["しゃしんをけす？"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "消す前に確かめる")
        alert.buttons["けす"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["ピースのうら、しゃしんはまだないよ"].waitForExistence(timeout: 5), "写真を消した裏側")
        XCTAssertTrue(app.buttons["しゃしんをえらぶ"].exists)
    }
}
