//
//  PieceNotificationResponder.swift
//  demomoni-remake-ios
//

import Foundation
import UserNotifications

/// 近くのピースの通知を開いたときに、さがすタブに切り替える（`UNUserNotificationCenter` の delegate）。
/// アプリが終了していて通知から起動したときも届くよう、`DemomoniApp.init` で delegate にする
final class PieceNotificationResponder: NSObject, UNUserNotificationCenterDelegate {
    private let tabSelection: TabSelection

    init(tabSelection: TabSelection) {
        self.tabSelection = tabSelection
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let request = response.notification.request
        guard let tab = AppTab.forNotification(identifier: request.identifier, userInfo: request.content.userInfo) else {
            return
        }
        await show(tab)
    }

    /// タブを切り替える。シート（なぞなぞの詳細・ピース詳細など）が開いていても閉じず、タブだけを切り替える
    private func show(_ tab: AppTab) {
        tabSelection.selected = tab
    }
}
