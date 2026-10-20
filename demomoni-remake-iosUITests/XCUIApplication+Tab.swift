//
//  XCUIApplication+Tab.swift
//  demomoni-remake-iosUITests
//

import XCTest

extension XCUIApplication {
    /// タブのボタン。iPhone では下のタブバー（`tabBars`）に、iPad では画面の上のタブバーにあり、
    /// iPad のほうは `tabBars` に入らないので、ラベルで探す
    func tabButton(_ title: String) -> XCUIElement {
        let inTabBar = tabBars.buttons[title]
        if inTabBar.exists {
            return inTabBar
        }
        return buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
    }
}
