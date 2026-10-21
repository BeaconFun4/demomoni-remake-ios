//
//  NearbyAlertPermissionStatusTests.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import Testing

/// せっていタブのスイッチの下に出す、許可が足りないときの案内
struct NearbyAlertPermissionStatusTests {
    private let sufficient = NearbyAlertPermissionStatus(isLocationAlways: true, hasFullAccuracy: true, areNotificationsAllowed: true)

    /// オフのとき・許可の状態をまだ読んでいないとき・許可がそろっているときは案内を出さない
    @Test
    func noMessage() {
        let insufficient = NearbyAlertPermissionStatus(isLocationAlways: false, hasFullAccuracy: false, areNotificationsAllowed: false)
        #expect(NearbyAlertPermissionStatus.message(isEnabled: false, status: insufficient) == nil)
        #expect(NearbyAlertPermissionStatus.message(isEnabled: true, status: nil) == nil)
        #expect(NearbyAlertPermissionStatus.message(isEnabled: true, status: sufficient) == nil)
        #expect(sufficient.isSufficient)
        #expect(!insufficient.isSufficient)
    }

    /// 位置情報が「常に」でなければ、そのことを案内する（正確な位置情報より先に直してもらう）
    @Test
    func asksForAlwaysLocation() {
        var status = sufficient
        status.isLocationAlways = false
        status.hasFullAccuracy = false
        #expect(NearbyAlertPermissionStatus.message(isEnabled: true, status: status) == "おしらせするには、\n位置情報を「常に」にしてね")
    }

    /// 「常に」でも、正確な位置情報がオフならオンにしてもらう
    @Test
    func asksForFullAccuracy() {
        var status = sufficient
        status.hasFullAccuracy = false
        #expect(NearbyAlertPermissionStatus.message(isEnabled: true, status: status) == "おしらせするには、\n「正確な位置情報」をオンにしてね")
    }

    /// 通知が許可されていなければ、そのことを案内する。位置情報と両方足りなければ両方
    @Test
    func asksForNotifications() {
        var status = sufficient
        status.areNotificationsAllowed = false
        #expect(NearbyAlertPermissionStatus.message(isEnabled: true, status: status) == "おしらせするには、\n通知を許可してね")

        status.isLocationAlways = false
        #expect(NearbyAlertPermissionStatus.message(isEnabled: true, status: status) == "おしらせするには、\n位置情報を「常に」にしてね\n通知を許可してね")
    }
}
