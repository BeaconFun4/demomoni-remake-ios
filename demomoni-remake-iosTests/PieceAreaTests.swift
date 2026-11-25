//
//  PieceAreaTests.swift
//  demomoni-remake-iosTests
//

import CoreLocation
@testable import demomoni_remake_ios
import Foundation
import Testing

/// ピースの場所の範囲の判定
struct PieceAreaTests {
    private let catalog = Catalog.bundled
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// 函館山（いちばん近いほかのピースまで 700 m 以上ある）
    private var hakodateyama: Piece {
        catalog.pieces[1]
    }

    /// 精度のよい、今測った位置
    private func fix(at coordinate: Coordinate, accuracy: Double = 10, age: TimeInterval = 0) -> LocationFix {
        LocationFix(coordinate: coordinate, horizontalAccuracy: accuracy, timestamp: now.addingTimeInterval(-age))
    }

    /// 北へ `meters` だけ動かした位置（緯度 1 度はおよそ 111 km）
    private func north(of coordinate: Coordinate, meters: Double) -> Coordinate {
        Coordinate(latitude: coordinate.latitude + meters / 111_000, longitude: coordinate.longitude)
    }

    /// 2 点の距離は CoreLocation と同じ値。同じ点なら 0
    @Test
    func distanceMatchesCoreLocation() {
        let tower = Coordinate(latitude: 41.7945, longitude: 140.7539)
        let station = Coordinate(latitude: 41.7737, longitude: 140.7266)
        let expected = CLLocation(latitude: 41.7945, longitude: 140.7539)
            .distance(from: CLLocation(latitude: 41.7737, longitude: 140.7266))
        #expect(tower.distance(to: station) == expected)
        #expect(station.distance(to: tower) == expected)
        #expect(tower.distance(to: tower) == 0)
        // 五稜郭タワーから函館駅まではおよそ 3 km
        #expect((3_000...3_400).contains(expected))
    }

    /// ピースの場所から半径 100 m の内側ならゲットでき、外側ならできない
    @Test
    func detectsPieceWithinRadius() {
        let center = hakodateyama.coordinate
        #expect(PieceArea.radius == 100)
        #expect(PieceArea.pieces(around: fix(at: center), in: catalog.pieces, now: now) == [hakodateyama])
        #expect(PieceArea.pieces(around: fix(at: north(of: center, meters: 90)), in: catalog.pieces, now: now) == [hakodateyama])
        #expect(PieceArea.pieces(around: fix(at: north(of: center, meters: 110)), in: catalog.pieces, now: now).isEmpty)
    }

    /// 範囲が重なる場所では、範囲に入ったピースを近い順に並べる（獲得済みかは見ない）
    @Test
    func ordersOverlappingPiecesByDistance() throws {
        let magistrate = try #require(catalog.pieces.first { $0.name == "箱館奉行所" })
        let names = PieceArea.pieces(around: fix(at: magistrate.coordinate), in: catalog.pieces, now: now).map(\.name)
        // 箱館奉行所は五稜郭公園の中（公園の中心から 24 m）
        #expect(names == ["箱館奉行所", "五稜郭公園"])
    }

    /// どのピースの範囲にも入っていなければ空
    @Test
    func detectsNothingFarFromPieces() {
        let tokyo = Coordinate(latitude: 35.681236, longitude: 139.767125)
        #expect(PieceArea.pieces(around: fix(at: tokyo), in: catalog.pieces, now: now).isEmpty)
    }

    /// 精度が 100 m より悪い位置・無効な位置（精度が負）は使わない
    @Test(arguments: [(-1.0, false), (0, true), (100, true), (101, false), (1_000, false)])
    func usesOnlyAccurateFix(accuracy: Double, isUsable: Bool) {
        let fix = fix(at: hakodateyama.coordinate, accuracy: accuracy)
        #expect(PieceArea.isUsable(fix, now: now) == isUsable)
        #expect(PieceArea.pieces(around: fix, in: catalog.pieces, now: now).isEmpty == !isUsable)
    }

    /// 30 秒より前に測った位置（位置情報を使い始めた直後に届く古い位置）は使わない
    @Test(arguments: [(0.0, true), (30, true), (31, false), (3_600, false)])
    func usesOnlyRecentFix(age: TimeInterval, isUsable: Bool) {
        let fix = fix(at: hakodateyama.coordinate, age: age)
        #expect(PieceArea.isUsable(fix, now: now) == isUsable)
        #expect(PieceArea.pieces(around: fix, in: catalog.pieces, now: now).isEmpty == !isUsable)
    }

    /// ピースの緯度・経度を、範囲の中心にする
    @Test
    func pieceCoordinate() {
        #expect(hakodateyama.coordinate == Coordinate(latitude: 41.759430, longitude: 140.704641))
    }

    /// CoreLocation の位置から、緯度・経度・精度・日時を写す
    @Test
    func makesFixFromCoreLocation() {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 41.7737, longitude: 140.7266),
            altitude: 0,
            horizontalAccuracy: 12,
            verticalAccuracy: 5,
            timestamp: now
        )
        #expect(LocationFix(location) == LocationFix(
            coordinate: Coordinate(latitude: 41.7737, longitude: 140.7266),
            horizontalAccuracy: 12,
            timestamp: now
        ))
    }
}
