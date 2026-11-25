//
//  NearbyPieceMonitoringTests.swift
//  demomoni-remake-iosTests
//

import CoreLocation
@testable import demomoni_remake_ios
import Foundation
import Testing

/// 「アプリを閉じていても近くのピースを知らせる」の判定
struct NearbyPieceMonitoringTests {
    private let catalog = Catalog.bundled

    /// 大沼公園の場所（函館の市街から 20 km ほど北）
    private let onumaPark = Coordinate(latitude: 41.979, longitude: 140.669)

    /// 範囲に入った出来事
    private func insideEvent(pieceID: Int) throws -> RegionEvent {
        RegionEvent(identifier: NearbyPieceMonitoring.identifier(for: try #require(catalog.piece(id: pieceID))), state: .inside)
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

    /// まだ獲得していないピースが上限に収まれば、すべてのピースの場所を半径 100 m の円で見張る
    @Test
    func conditionsForEveryPieceWithinLimit() throws {
        let collected = Set(catalog.pieces.map(\.id)).subtracting([0, 1])
        let conditions = NearbyPieceMonitoring.conditions(pieces: catalog.pieces, collectedPieceIDs: collected, near: nil)
        #expect(conditions == [
            MonitoredRegion(
                identifier: "area-0-41.765501-140.709514-100.000000",
                center: Coordinate(latitude: 41.765501, longitude: 140.709514),
                radius: 100
            ),
            MonitoredRegion(
                identifier: "area-1-41.759430-140.704641-100.000000",
                center: Coordinate(latitude: 41.759430, longitude: 140.704641),
                radius: 100
            )
        ])
    }

    /// 上限ちょうどまでは、今いる場所によらずすべてを見張る（選び直す円は要らない）
    @Test
    func conditionsForEveryPieceAtLimit() {
        let uncollected = Set(catalog.pieces.prefix(NearbyPieceMonitoring.conditionLimit).map(\.id))
        let collected = Set(catalog.pieces.map(\.id)).subtracting(uncollected)
        let conditions = NearbyPieceMonitoring.conditions(pieces: catalog.pieces, collectedPieceIDs: collected, near: onumaPark)
        #expect(conditions.count == NearbyPieceMonitoring.conditionLimit)
        #expect(conditions.allSatisfy { $0.identifier.hasPrefix("area-") })
    }

    /// 上限を超えるとき（32 か所をまだ 1 つも獲得していないとき）は、今いる場所に近い 19 か所と、選び直す円を見張る。
    /// 選び直す円は、選ばなかったピースの範囲に届かない
    @Test
    func conditionsNearLocationOverLimit() throws {
        let conditions = NearbyPieceMonitoring.conditions(pieces: catalog.pieces, collectedPieceIDs: [], near: onumaPark)
        #expect(conditions.count == NearbyPieceMonitoring.conditionLimit)

        let areas = conditions.dropLast()
        let monitoredIdentifiers = Set(areas.map(\.identifier))
        let monitoredNames = catalog.pieces
            .filter { monitoredIdentifiers.contains(NearbyPieceMonitoring.identifier(for: $0)) }
            .map(\.name)
        #expect(monitoredNames.count == NearbyPieceMonitoring.conditionLimit - 1)
        // 大沼の 4 か所と、北斗のうち内陸の 3 か所は、大沼公園から近いので選ぶ（函館の市街は 20 km 以上離れている）
        for name in ["大沼公園", "大沼国際交流プラザ", "東大沼キャンプ場", "じゅんさい沼", "新函館北斗駅", "きじひき高原", "北斗市総合文化センター"] {
            #expect(monitoredNames.contains(name), "\(name) を見張る")
        }

        let boundary = try #require(conditions.last)
        #expect(boundary.identifier.hasPrefix(NearbyPieceMonitoring.boundaryIdentifierPrefix))
        #expect(boundary.center == onumaPark)
        let unmonitored = catalog.pieces.filter { !monitoredNames.contains($0.name) }
        #expect(unmonitored.count == catalog.pieces.count - NearbyPieceMonitoring.conditionLimit + 1)
        for piece in unmonitored {
            #expect(onumaPark.distance(to: piece.coordinate) >= boundary.radius + PieceArea.radius, "\(piece.name) の範囲に届かない")
        }
        // いちばん近い選ばなかったピースの範囲の手前まで
        let nearestUnmonitored = try #require(unmonitored.map { onumaPark.distance(to: $0.coordinate) }.min())
        #expect(abs(boundary.radius - (nearestUnmonitored - PieceArea.radius)) < 0.001)
    }

    /// 上限を超えるのに今いる場所が分からなければ、同梱データの順に上限まで見張る
    @Test
    func conditionsWithoutLocationOverLimit() {
        let conditions = NearbyPieceMonitoring.conditions(pieces: catalog.pieces, collectedPieceIDs: [], near: nil)
        let expected = catalog.pieces.prefix(NearbyPieceMonitoring.conditionLimit).map(NearbyPieceMonitoring.identifier(for:))
        #expect(conditions.map(\.identifier) == expected)
    }

    /// 選び直す円は、選ばなかったピースが近くても 200 m より小さくしない
    @Test
    func boundaryHasMinimumRadius() throws {
        let here = Coordinate(latitude: 41.7737, longitude: 140.7266)
        let pieces = (0..<3).map {
            Piece(id: $0, name: "\($0)", latitude: here.latitude, longitude: here.longitude, area: "", image: "piece1")
        }
        let conditions = NearbyPieceMonitoring.conditions(pieces: pieces, collectedPieceIDs: [], near: here, limit: 2)
        #expect(conditions.map(\.identifier) == [
            NearbyPieceMonitoring.identifier(for: pieces[0]),
            NearbyPieceMonitoring.boundaryIdentifier(center: here, radius: NearbyPieceMonitoring.minimumBoundaryRadius)
        ])
        #expect(conditions.last?.radius == NearbyPieceMonitoring.minimumBoundaryRadius)
    }

    /// 全部獲得したら、何も見張らない
    @Test
    func noConditionsWhenAllCollected() {
        let allPieceIDs = Set(catalog.pieces.map(\.id))
        #expect(NearbyPieceMonitoring.conditions(pieces: catalog.pieces, collectedPieceIDs: allPieceIDs, near: onumaPark).isEmpty)
    }

    /// 円の条件の identifier にはピースの id・緯度・経度・半径が入る
    /// （同梱データの場所が変わったら identifier も変わり、古い条件を外して足し直す）。選び直す円は中心と半径が入る
    @Test
    func identifiersIncludeCenterAndRadius() throws {
        let piece = try #require(catalog.piece(id: 14))
        #expect(NearbyPieceMonitoring.identifier(for: piece) == "area-14-41.765038-140.708921-100.000000")
        let moved = Piece(id: 14, name: piece.name, latitude: 41.7645, longitude: piece.longitude, area: piece.area, image: piece.image)
        #expect(NearbyPieceMonitoring.identifier(for: moved) != NearbyPieceMonitoring.identifier(for: piece))
        #expect(NearbyPieceMonitoring.boundaryIdentifier(center: onumaPark, radius: 1_234.5) == "boundary-41.979000-140.669000-1234.500000")
    }

    /// ピースの場所の円に入ったら、そのピースを知らせる
    @Test
    func notifiesPieceForArea() throws {
        let piece = NearbyPieceMonitoring.pieceToNotify(
            for: try insideEvent(pieceID: 1),
            catalog: catalog,
            collectedPieceIDs: [],
            isAppActive: false
        )
        #expect(piece?.name == "函館山")
    }

    /// 獲得済みのピース・円から出たとき・状態が分からないとき・アプリが前面のときは知らせない。
    /// 同梱データの今の場所でない条件（前の版のビーコンの条件・場所を変える前の条件）・選び直す円でも知らせない
    @Test
    func doesNotNotify() throws {
        let inside = try insideEvent(pieceID: 0)
        #expect(NearbyPieceMonitoring.pieceToNotify(for: inside, catalog: catalog, collectedPieceIDs: [0], isAppActive: false) == nil)
        #expect(NearbyPieceMonitoring.pieceToNotify(for: inside, catalog: catalog, collectedPieceIDs: [], isAppActive: true) == nil)

        for state in [RegionEvent.State.outside, .unknown] {
            let event = RegionEvent(identifier: inside.identifier, state: state)
            #expect(NearbyPieceMonitoring.pieceToNotify(for: event, catalog: catalog, collectedPieceIDs: [], isAppActive: false) == nil)
        }

        for identifier in [
            "beacon-E8C65602-6D9C-44EF-9734-B2D3EF1CD961-0-5000",
            "area-0-41.000000-140.000000-100.000000",
            NearbyPieceMonitoring.boundaryIdentifier(center: onumaPark, radius: 500)
        ] {
            let event = RegionEvent(identifier: identifier, state: .inside)
            #expect(NearbyPieceMonitoring.pieceToNotify(for: event, catalog: catalog, collectedPieceIDs: [], isAppActive: false) == nil)
        }
    }

    /// 選び直す円から出たときだけ選び直す（入った・分からない・ピースの円から出たときは選び直さない）
    @Test
    func reselectsOnlyWhenLeavingBoundary() throws {
        let boundary = NearbyPieceMonitoring.boundaryIdentifier(center: onumaPark, radius: 500)
        #expect(NearbyPieceMonitoring.needsReselection(after: RegionEvent(identifier: boundary, state: .outside)))
        #expect(!NearbyPieceMonitoring.needsReselection(after: RegionEvent(identifier: boundary, state: .inside)))
        #expect(!NearbyPieceMonitoring.needsReselection(after: RegionEvent(identifier: boundary, state: .unknown)))
        let area = try insideEvent(pieceID: 0).identifier
        #expect(!NearbyPieceMonitoring.needsReselection(after: RegionEvent(identifier: area, state: .outside)))
    }

    /// CLMonitor の条件の状態を、入った・出た・分からないに直す
    @Test(arguments: [
        (CLMonitor.Event.State.satisfied, RegionEvent.State.inside),
        (.unsatisfied, .outside),
        (.unknown, .unknown),
        (.unmonitored, .unknown)
    ])
    func mapsMonitorState(state: CLMonitor.Event.State, expected: RegionEvent.State) {
        #expect(RegionEvent.State(state) == expected)
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

/// CLMonitor を開いてよいかの判定（#120）
struct CanOpenMonitorTests {
    /// 位置情報が「常に」か「使用中」のときだけ開く。未決定・拒否・制限・分からない値では開かない
    @Test(arguments: [
        (LocationAuthorization.always, true),
        (.whenInUse, true),
        (.notDetermined, false),
        (.denied, false),
        (.restricted, false),
        (.unknown, false)
    ])
    func opensOnlyWhenAuthorized(authorization: LocationAuthorization, expected: Bool) {
        #expect(NearbyPieceMonitoring.canOpenMonitor(authorization) == expected)
    }

    /// CoreLocation の許可の状態を写す。今の SDK に無い値は `unknown` にする
    @Test(arguments: [
        (CLAuthorizationStatus.notDetermined, LocationAuthorization.notDetermined),
        (.restricted, .restricted),
        (.denied, .denied),
        (.authorizedAlways, .always),
        (.authorizedWhenInUse, .whenInUse)
    ])
    func mapsAuthorizationStatus(status: CLAuthorizationStatus, expected: LocationAuthorization) {
        #expect(LocationAuthorization(status) == expected)
    }

    @Test
    func mapsUnknownAuthorizationStatus() throws {
        let unknown = try #require(CLAuthorizationStatus(rawValue: 99))
        #expect(LocationAuthorization(unknown) == .unknown)
        #expect(!NearbyPieceMonitoring.canOpenMonitor(LocationAuthorization(unknown)))
    }
}

/// スイッチの値の保存
@MainActor
struct NearbyPieceAlertPreferenceTests {
    /// 既定はオフ・条件なし。切り替えたら端末に保存し、次に読んだときも同じ値
    @Test
    func storesValue() throws {
        let suiteName = "NearbyPieceAlertPreferenceTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preference = NearbyPieceAlertPreference(defaults: defaults)
        #expect(!preference.isEnabled)
        #expect(!preference.mayHaveConditions)

        preference.isEnabled = true
        preference.mayHaveConditions = true
        let reloaded = NearbyPieceAlertPreference(defaults: defaults)
        #expect(reloaded.isEnabled)
        #expect(reloaded.mayHaveConditions)

        preference.mayHaveConditions = false
        #expect(!NearbyPieceAlertPreference(defaults: defaults).mayHaveConditions)
    }

    /// 保存先が無ければ、メモリ上だけで持つ（端末の値を読まず、書かない）
    @Test
    func keepsValueInMemoryWithoutDefaults() {
        let preference = NearbyPieceAlertPreference(defaults: nil)
        preference.isEnabled = true
        preference.mayHaveConditions = true
        #expect(preference.isEnabled)
        #expect(preference.mayHaveConditions)
        let other = NearbyPieceAlertPreference(defaults: nil)
        #expect(!other.isEnabled)
        #expect(!other.mayHaveConditions)
    }
}
