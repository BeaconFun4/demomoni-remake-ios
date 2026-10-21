//
//  SettingsUITests.swift
//  demomoni-remake-iosUITests
//

import XCTest

final class SettingsUITests: XCTestCase {
    override func setUpWithError() throws {
        // UI テストでは失敗した時点で即座に止める
        continueAfterFailure = false
    }

    /// せっていタブにバージョンが出て、ニコモジ+ を押すとライセンスの本文が出る
    @MainActor
    func testShowsVersionAndFontLicense() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        app.tabButton("せってい").tap()
        XCTAssertTrue(app.navigationBars["せってい"].waitForExistence(timeout: 5))
        // LabeledContent はラベルと値が 1 つの要素にまとまることがあるので、ラベルの一部で探す
        let version = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "バージョン")).firstMatch
        XCTAssertTrue(version.waitForExistence(timeout: 5))

        app.buttons["ニコモジ+（SIL OFL 1.1）"].tap()
        XCTAssertTrue(app.navigationBars["ニコモジ+"].waitForExistence(timeout: 5))
        let license = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "SIL OPEN FONT LICENSE")).firstMatch
        XCTAssertTrue(license.waitForExistence(timeout: 5))
    }

    /// 近くのピースを知らせるスイッチがあって既定はオフ。オンにすると、許可が足りないことの案内と「設定をひらく」が出る。
    /// `-uiTesting` では本物の許可を尋ねず、許可が無いものとして動く
    @MainActor
    func testNearbyPieceAlertSwitch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        app.tabButton("せってい").tap()
        let toggle = app.switches["アプリを閉じていても、近くのピースを知らせる"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertFalse(app.buttons["設定をひらく"].exists)

        // List の行の Toggle は、行ではなく中のスイッチを押す
        toggle.switches.firstMatch.tap()
        XCTAssertEqual(toggle.value as? String, "1")
        let notice = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "通知を許可してね")).firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["設定をひらく"].exists)

        toggle.switches.firstMatch.tap()
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertTrue(notice.waitForNonExistence(timeout: 5))
    }
}
