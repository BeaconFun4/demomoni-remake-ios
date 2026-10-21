//
//  PieceNotifier.swift
//  demomoni-remake-ios
//

import Foundation
import UserNotifications

/// 近くのピースをローカル通知で知らせる仕組み。実機では `UNUserNotificationCenter`、
/// UI テストと Unit テストのホストでは何もしないもの（`InactivePieceNotifier`）に差し替える
protocol PieceNotifier: AnyObject {
    /// 通知が許可されているか
    func areNotificationsAllowed() async -> Bool
    /// 通知を出す。同じ identifier の通知があれば置き換える
    func post(_ notification: PieceNotificationContent) async
}

/// `UNUserNotificationCenter` でローカル通知を出す（Push 通知は使わない）
final class UserNotificationPieceNotifier: PieceNotifier {
    func areNotificationsAllowed() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied:
            return false
        @unknown default:
            return false
        }
    }

    func post(_ notification: PieceNotificationContent) async {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default
        content.userInfo = [NearbyPieceMonitoring.pieceIDKey: notification.pieceID]
        let request = UNNotificationRequest(identifier: notification.identifier, content: content, trigger: nil)
        // 出せなくても、さがすタブで獲得できるので何もしない
        try? await UNUserNotificationCenter.current().add(request)
    }
}

/// 何もしない通知。UI テストと Unit テストのホストで使う
final class InactivePieceNotifier: PieceNotifier {
    func areNotificationsAllowed() async -> Bool {
        false
    }

    func post(_ notification: PieceNotificationContent) async {}
}
