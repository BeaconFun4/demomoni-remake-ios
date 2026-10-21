//
//  DebugModeUITests.swift
//  demomoni-remake-iosUITests
//

import XCTest

/// せっていタブのデバッグモード。UI テストは Debug 構成のアプリで動くので、デバッグモードがある
final class DebugModeUITests: XCTestCase {
    override func setUpWithError() throws {
        // UI テストでは失敗した時点で即座に止める
        continueAfterFailure = false
    }

    @MainActor
    private func openDebugMode(_ app: XCUIApplication) {
        app.tabButton("せってい").tap()
        let link = app.buttons["デバッグモード"]
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap()
        XCTAssertTrue(app.navigationBars["デバッグモード"].waitForExistence(timeout: 5))
    }

    /// Toggle の行の中のスイッチ（無ければ行そのもの）
    @MainActor
    private func toggleSwitch(_ app: XCUIApplication, _ title: String) -> XCUIElement {
        let row = app.switches[title]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "\(title) のスイッチ")
        let inner = row.switches.firstMatch
        return inner.exists ? inner : row
    }

    /// ピースを選んで擬似検知すると、さがすタブに切り替わり「ピースをゲットしたよ！！」が出て、獲得が保存される
    @MainActor
    func testFakeDetectionShowsGotPiece() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        openDebugMode(app)
        app.buttons["ピースを選んで擬似検知する"].tap()
        let tower = app.buttons["No.2 五稜郭タワー"]
        XCTAssertTrue(tower.waitForExistence(timeout: 5))
        tower.tap()

        let title = app.staticTexts["ピースをゲットしたよ！！"]
        XCTAssertTrue(title.waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["五稜郭タワー"].exists)
        app.buttons["とじる"].tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 5))

        // さがすタブにいて、獲得したピースが盤に出る
        XCTAssertTrue(app.staticTexts["まちをあるいてみよう！！"].waitForExistence(timeout: 5))
        app.tabButton("いちらん").tap()
        XCTAssertTrue(app.buttons["ピース No.2 五稜郭タワー"].waitForExistence(timeout: 5))

        // 獲得したピースは、擬似検知の一覧から消える
        app.tabButton("せってい").tap()
        XCTAssertTrue(app.navigationBars["擬似検知"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["No.2 五稜郭タワー"].exists)
    }

    /// ピースを 1 つ埋めると盤に出て、外すと消える
    @MainActor
    func testFillAndRemoveOnePiece() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        openDebugMode(app)
        let hakodateyama = app.switches["No.1 函館山"]
        toggleSwitch(app, "No.1 函館山").tap()
        XCTAssertEqual(hakodateyama.value as? String, "1")

        app.tabButton("いちらん").tap()
        XCTAssertTrue(app.buttons["ピース No.1 函館山"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["ピース No.14 元町公園"].exists)

        app.tabButton("せってい").tap()
        toggleSwitch(app, "No.1 函館山").tap()
        XCTAssertEqual(hakodateyama.value as? String, "0")

        app.tabButton("いちらん").tap()
        XCTAssertTrue(app.navigationBars["いちらん"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["ピース No.1 函館山"].exists)
    }

    /// 全部埋めると盤にすべてのピースが出て、全部リセットは確認してから全部消す
    @MainActor
    func testFillAllAndResetAll() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        openDebugMode(app)
        app.buttons["全部埋める"].tap()
        XCTAssertTrue(app.staticTexts["ぜんぶ（32 / 32 こ）"].waitForExistence(timeout: 5))

        app.tabButton("いちらん").tap()
        XCTAssertTrue(app.buttons["ピース No.1 函館山"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["ピース No.14 元町公園"].exists)

        app.tabButton("せってい").tap()
        app.buttons["全部リセット"].tap()
        let confirm = app.buttons["全部リセットする"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(app.staticTexts["ぜんぶ（0 / 32 こ）"].waitForExistence(timeout: 5))

        app.tabButton("いちらん").tap()
        XCTAssertTrue(app.navigationBars["いちらん"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["ピース No.1 函館山"].exists)
        XCTAssertFalse(app.buttons["ピース No.14 元町公園"].exists)
    }
}
