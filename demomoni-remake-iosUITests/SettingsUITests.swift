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
}
