//
//  NearbyPieceMonitoringTests.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import Foundation
import Testing

/// 「アプリを閉じていても近くのピースを知らせる」の判定
struct NearbyPieceMonitoringTests {
    private let catalog = Catalog.bundled
    private let uuid = UUID(uuidString: "E8C65602-6D9C-44EF-9734-B2D3EF1CD961")!

    /// 元町公園（beaconId 0）のビーコン
    private var motomachi: DetectedBeacon {
        DetectedBeacon(uuid: uuid, major: 0, minor: 5000)
    }

    /// スイッチがオンで、位置情報が「常に」・通知が許可されているときだけ見張る
    @Test(arguments: [false, true], [false, true])
    func monitorsOnlyWhenEnabledAndAuthorized(isLocationAlwaysAuthorized: Bool, areNotificationsAllowed: Bool) {
        #expect(NearbyPieceMonitoring.shouldMonitor(
            isEnabled: true,
            isLocationAlwaysAuthorized: isLocationAlwaysAuthorized,
            areNotificationsAllowed: areNotificationsAllowed
        ) == (isLocationAlwaysAuthorized && areNotificationsAllowed))
        #expect(!NearbyPieceMonitoring.shouldMonitor(
            isEnabled: false,
            isLocationAlwaysAuthorized: isLocationAlwaysAuthorized,
            areNotificationsAllowed: areNotificationsAllowed
        ))
    }

    /// まだ獲得していないピースのビーコンが上限に収まれば、1 台ずつ見張る
    @Test
    func conditionsPerBeaconWithinLimit() {
        let collected = Set(catalog.pieces.map(\.id)).subtracting([0, 1])
        let conditions = NearbyPieceMonitoring.conditions(beacons: catalog.beacons, collectedPieceIDs: collected)
        #expect(conditions == [
            MonitoredBeacon(identifier: "beacon-\(uuid.uuidString)-0-5000", uuid: uuid, major: 0, minor: 5000),
            MonitoredBeacon(identifier: "beacon-\(uuid.uuidString)-0-6000", uuid: uuid, major: 0, minor: 6000)
        ])
    }

    /// 上限ちょうどまでは 1 台ずつ見張る
    @Test
    func conditionsPerBeaconAtLimit() {
        let uncollected = Set(catalog.pieces.prefix(NearbyPieceMonitoring.conditionLimit).map(\.id))
        let collected = Set(catalog.pieces.map(\.id)).subtracting(uncollected)
        let conditions = NearbyPieceMonitoring.conditions(beacons: catalog.beacons, collectedPieceIDs: collected)
        #expect(conditions.count == NearbyPieceMonitoring.conditionLimit)
        #expect(conditions.allSatisfy { $0.minor != nil })
    }

    /// 上限を超えるとき（同梱の 32 台をまだ 1 つも獲得していないとき）は、UUID ごとにまとめて見張る
    @Test
    func conditionsPerUUIDOverLimit() {
        #expect(catalog.beacons.count > NearbyPieceMonitoring.conditionLimit)
        let conditions = NearbyPieceMonitoring.conditions(beacons: catalog.beacons, collectedPieceIDs: [])
        #expect(conditions == [MonitoredBeacon(identifier: "beacon-uuid-\(uuid.uuidString)", uuid: uuid, major: nil, minor: nil)])
    }

    /// 全部獲得したら、何も見張らない
    @Test
    func noConditionsWhenAllCollected() {
        let allPieceIDs = Set(catalog.pieces.map(\.id))
        let conditions = NearbyPieceMonitoring.conditions(beacons: catalog.beacons, collectedPieceIDs: allPieceIDs)
        #expect(conditions.isEmpty)
    }

    /// ビーコン 1 台の条件の identifier には UUID・major・minor が入り、そこからビーコンを読める
    /// （同梱データの値が変わったら identifier も変わり、古い条件を外して足し直す）
    @Test
    func readsBeaconFromIdentifier() throws {
        let beacon = try #require(catalog.beacons.first { $0.beaconId == 14 })
        let identifier = NearbyPieceMonitoring.identifier(for: beacon)
        #expect(NearbyPieceMonitoring.beacon(fromIdentifier: identifier) == DetectedBeacon(beacon))

        let moved = Beacon(beaconId: 14, uuid: beacon.uuid, major: beacon.major, minor: beacon.minor + 1)
        #expect(NearbyPieceMonitoring.identifier(for: moved) != identifier)

        #expect(NearbyPieceMonitoring.beacon(fromIdentifier: NearbyPieceMonitoring.identifier(uuid: uuid)) == nil)
        #expect(NearbyPieceMonitoring.beacon(fromIdentifier: "beacon-14") == nil)
        #expect(NearbyPieceMonitoring.beacon(fromIdentifier: "other") == nil)
    }

    /// ビーコン 1 台の条件の範囲に入ったら、そのピースを知らせる
    @Test
    func notifiesPieceForBeaconCondition() {
        let event = BeaconRegionEvent(identifier: "beacon-\(uuid.uuidString)-0-6000", isInside: true, beacon: nil)
        let piece = NearbyPieceMonitoring.pieceToNotify(for: event, catalog: catalog, collectedPieceIDs: [], isAppActive: false)
        #expect(piece?.name == "函館山")
    }

    /// UUID ごとの条件では、`refinement` のビーコンのピースを知らせる。どのビーコンか分からなければ知らせない
    @Test
    func notifiesPieceForRefinement() {
        let identifier = NearbyPieceMonitoring.identifier(uuid: uuid)
        let refined = BeaconRegionEvent(identifier: identifier, isInside: true, beacon: motomachi)
        let piece = NearbyPieceMonitoring.pieceToNotify(for: refined, catalog: catalog, collectedPieceIDs: [], isAppActive: false)
        #expect(piece?.name == "元町公園")

        let unknown = BeaconRegionEvent(identifier: identifier, isInside: true, beacon: nil)
        #expect(NearbyPieceMonitoring.pieceToNotify(for: unknown, catalog: catalog, collectedPieceIDs: [], isAppActive: false) == nil)
    }

    /// 獲得済みのピース・範囲から出たとき・アプリが前面のとき・同梱データに無いビーコンでは知らせない
    @Test
    func doesNotNotify() {
        let inside = BeaconRegionEvent(identifier: "beacon-\(uuid.uuidString)-0-5000", isInside: true, beacon: nil)
        #expect(NearbyPieceMonitoring.pieceToNotify(for: inside, catalog: catalog, collectedPieceIDs: [0], isAppActive: false) == nil)
        #expect(NearbyPieceMonitoring.pieceToNotify(for: inside, catalog: catalog, collectedPieceIDs: [], isAppActive: true) == nil)

        let outside = BeaconRegionEvent(identifier: "beacon-\(uuid.uuidString)-0-5000", isInside: false, beacon: nil)
        #expect(NearbyPieceMonitoring.pieceToNotify(for: outside, catalog: catalog, collectedPieceIDs: [], isAppActive: false) == nil)

        let unknownBeacon = BeaconRegionEvent(identifier: "beacon-\(uuid.uuidString)-0-4000", isInside: true, beacon: nil)
        #expect(NearbyPieceMonitoring.pieceToNotify(for: unknownBeacon, catalog: catalog, collectedPieceIDs: [], isAppActive: false) == nil)

        let notInCatalog = BeaconRegionEvent(
            identifier: NearbyPieceMonitoring.identifier(uuid: uuid),
            isInside: true,
            beacon: DetectedBeacon(uuid: uuid, major: 0, minor: 4000)
        )
        #expect(NearbyPieceMonitoring.pieceToNotify(for: notInCatalog, catalog: catalog, collectedPieceIDs: [], isAppActive: false) == nil)
    }

    /// 通知の identifier はピースごと（同じピースの通知を重ねない）。獲得はさがすタブで行うので、さがすタブへ案内する
    @Test
    func notificationContent() throws {
        let piece = try #require(catalog.piece(id: 14))
        let notification = NearbyPieceMonitoring.notification(for: piece)
        #expect(notification.identifier == "piece-14")
        #expect(notification.pieceID == 14)
        #expect(notification.title == "近くにピースがあるよ！")
        #expect(notification.body == "さがすタブをひらいて、ピースをゲットしよう")
        #expect(NearbyPieceMonitoring.notification(for: piece) == notification)
    }
}

/// スイッチの値の保存
@MainActor
struct NearbyPieceAlertPreferenceTests {
    /// 既定はオフ。切り替えたら端末に保存し、次に読んだときも同じ値
    @Test
    func storesValue() throws {
        let suiteName = "NearbyPieceAlertPreferenceTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preference = NearbyPieceAlertPreference(defaults: defaults)
        #expect(!preference.isEnabled)
        #expect(!preference.hasStoredValue)

        preference.isEnabled = true
        #expect(preference.hasStoredValue)
        #expect(NearbyPieceAlertPreference(defaults: defaults).isEnabled)
    }

    /// 保存先が無ければ、メモリ上だけで持つ
    @Test
    func keepsValueInMemoryWithoutDefaults() {
        let preference = NearbyPieceAlertPreference(defaults: nil)
        preference.isEnabled = true
        #expect(preference.isEnabled)
        #expect(!preference.hasStoredValue)
        #expect(!NearbyPieceAlertPreference(defaults: nil).isEnabled)
    }
}
