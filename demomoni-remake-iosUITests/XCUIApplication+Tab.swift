//
//  XCUIApplication+Tab.swift
//  demomoni-remake-iosUITests
//

import XCTest

extension XCUIApplication {
    /// タブのボタン。iPhone では下のタブバー（`tabBars`）に、iPad では画面の上のタブバーにあり、
    /// iPad のほうは `tabBars` に入らないので、ラベルで探す。起動の直後でも押せるよう、出るまで待つ
    func tabButton(_ title: String, timeout: TimeInterval = 10) -> XCUIElement {
        let byLabel = buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
        _ = byLabel.waitForExistence(timeout: timeout)
        let inTabBar = tabBars.buttons[title]
        return inTabBar.exists ? inTabBar : byLabel
    }
}
