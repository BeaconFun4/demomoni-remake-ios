//
//  NearbyAlertPermissionStatus.swift
//  demomoni-remake-ios
//

import Foundation

/// 「アプリを閉じていても近くのピースを知らせる」に要る許可の状態
nonisolated struct NearbyAlertPermissionStatus: Equatable, Sendable {
    /// 位置情報が「常に」か
    var isLocationAlways: Bool
    /// 正確な位置情報がオンか（オフだと iBeacon を見張れない）
    var hasFullAccuracy: Bool
    /// 通知が許可されているか
    var areNotificationsAllowed: Bool

    /// 見張って知らせるのに要る許可がそろっているか
    var isSufficient: Bool {
        isLocationAlways && hasFullAccuracy && areNotificationsAllowed
    }

    /// スイッチの下に出す案内。オフのとき・許可の状態をまだ読んでいないとき・許可がそろっているときは `nil`（案内を出さない）
    static func message(isEnabled: Bool, status: Self?) -> String? {
        guard isEnabled, let status, !status.isSufficient else {
            return nil
        }
        var lines = ["おしらせするには、"]
        if !status.isLocationAlways {
            lines.append("位置情報を「常に」にしてね")
        } else if !status.hasFullAccuracy {
            lines.append("「正確な位置情報」をオンにしてね")
        }
        if !status.areNotificationsAllowed {
            lines.append("通知を許可してね")
        }
        return lines.joined(separator: "\n")
    }
}
