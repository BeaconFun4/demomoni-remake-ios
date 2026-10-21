//
//  TabSelectionTests.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import Testing

/// 通知を開いたときに表示するタブ
struct TabSelectionTests {
    /// 近くのピースの通知なら、さがすタブを表示する
    @Test
    func showsSearchTabForPieceNotification() throws {
        let piece = try #require(Catalog.bundled.piece(id: 14))
        let notification = NearbyPieceMonitoring.notification(for: piece)
        let userInfo: [AnyHashable: Any] = [NearbyPieceMonitoring.pieceIDKey: notification.pieceID]
        #expect(AppTab.forNotification(identifier: notification.identifier, userInfo: userInfo) == .search)
        #expect(NearbyPieceMonitoring.pieceID(fromNotificationIdentifier: notification.identifier, userInfo: userInfo) == 14)
    }

    /// `userInfo` が無くても、identifier からピースの通知だと分かる
    @Test
    func readsPieceIDFromIdentifier() {
        #expect(NearbyPieceMonitoring.pieceID(fromNotificationIdentifier: "piece-3", userInfo: [:]) == 3)
        #expect(AppTab.forNotification(identifier: "piece-3", userInfo: [:]) == .search)
    }

    /// ほかの通知では、タブを切り替えない
    @Test
    func ignoresOtherNotifications() {
        #expect(AppTab.forNotification(identifier: "other", userInfo: [NearbyPieceMonitoring.pieceIDKey: 3]) == nil)
        #expect(NearbyPieceMonitoring.pieceID(fromNotificationIdentifier: "other", userInfo: [:]) == nil)
    }

    /// 起動したときは、さがすタブを表示する
    @MainActor
    @Test
    func startsWithSearchTab() {
        #expect(TabSelection().selected == .search)
    }
}
