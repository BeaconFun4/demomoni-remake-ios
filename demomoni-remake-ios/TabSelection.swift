//
//  TabSelection.swift
//  demomoni-remake-ios
//

import Foundation
import Observation

/// `ContentView` の 4 つのタブ
nonisolated enum AppTab: Hashable, Sendable {
    case riddle
    case search
    case pieceList
    case settings

    /// 通知を開いたときに表示するタブ。近くのピースの通知ならさがすタブ（獲得はさがすタブで行う）。ほかの通知なら `nil`（切り替えない）
    static func forNotification(identifier: String, userInfo: [AnyHashable: Any]) -> AppTab? {
        NearbyPieceMonitoring.pieceID(fromNotificationIdentifier: identifier, userInfo: userInfo) == nil ? nil : .search
    }
}

/// 表示しているタブ。通知を開いたとき・デバッグモードの擬似検知で、`ContentView` の外から切り替える
@Observable
final class TabSelection {
    /// 表示しているタブ。起動したときはさがすタブ
    var selected = AppTab.search
}
