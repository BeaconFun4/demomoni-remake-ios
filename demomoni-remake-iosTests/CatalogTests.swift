//
//  CatalogTests.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import Foundation
import Testing
import UIKit

/// テストのバンドル（同梱データの JSON が入っていない）を指すための型
private final class TestBundleToken {}

struct CatalogTests {
    private let beaconUUID = UUID(uuidString: "E8C65602-6D9C-44EF-9734-B2D3EF1CD961")!

    /// 同梱した 3 つの JSON を読める。ビーコンとピースは盤のマスと同じ 32 件。なぞなぞは元アプリのデータのまま 2 件
    @Test
    func loadsBundledData() throws {
        let catalog = try Catalog.load()
        #expect(catalog.beacons.count == 32)
        #expect(catalog.pieces.count == 32)
        #expect(catalog.riddles.count == 2)
    }

    /// 元アプリの 2 台のビーコンは、UUID・major・minor を元のデータのとおりに読む（獲得済みの記録が id で残っているので変えない）
    @Test
    func decodesBeacons() throws {
        let catalog = try Catalog.load()
        #expect(Array(catalog.beacons.prefix(2)) == [
            Beacon(beaconId: 0, uuid: beaconUUID, major: 0, minor: 5000),
            Beacon(beaconId: 1, uuid: beaconUUID, major: 0, minor: 6000)
        ])
    }

    /// 足したビーコンは仮の値で、UUID は元と同じ・major は 0・minor は 5000 + id × 1000
    @Test
    func beaconsFollowProvisionalRule() throws {
        let catalog = try Catalog.load()
        for beacon in catalog.beacons {
            #expect(beacon.uuid == beaconUUID, "beaconId \(beacon.beaconId) の UUID")
            #expect(beacon.major == 0, "beaconId \(beacon.beaconId) の major")
            #expect(Int(beacon.minor) == 5000 + beacon.beaconId * 1000, "beaconId \(beacon.beaconId) の minor")
        }
    }

    /// ピースの id は 0〜31 で、ビーコンの beaconId と 1 対 1 に対応する
    @Test
    func piecesAndBeaconsCorrespondOneToOne() throws {
        let catalog = try Catalog.load()
        let pieceIDs = catalog.pieces.map(\.id)
        let beaconIDs = catalog.beacons.map(\.beaconId)
        #expect(Set(pieceIDs).count == pieceIDs.count, "ピースの id が重複している")
        #expect(Set(beaconIDs).count == beaconIDs.count, "ビーコンの beaconId が重複している")
        #expect(Set(pieceIDs) == Set(0..<32))
        #expect(Set(pieceIDs) == Set(beaconIDs))
    }

    /// ピースの画像の番号は盤の 1〜32 を重複なく使い、画像はアセットにある
    @Test
    func pieceNumbersCoverBoardWithoutDuplicates() throws {
        let catalog = try Catalog.load()
        let numbers = catalog.pieces.compactMap(\.number)
        #expect(numbers.count == catalog.pieces.count, "番号の無いピースがある")
        #expect(numbers.sorted() == Array(PieceBoardLayout.numbers))
        for piece in catalog.pieces {
            #expect(UIImage(named: piece.image) != nil, "\(piece.image) のアセット")
        }
    }

    /// ビーコンの (UUID, major, minor) は重複しない（重複すると 1 台で 2 つのピースが取れてしまう）
    @Test
    func beaconIdentitiesAreUnique() throws {
        let catalog = try Catalog.load()
        let identities = catalog.beacons.map { "\($0.uuid)-\($0.major)-\($0.minor)" }
        #expect(Set(identities).count == identities.count)
    }

    /// 名所の配分は函館 24・大沼 4・北斗 4。名前は重複しない
    @Test
    func piecesAreSplitByRegion() throws {
        let catalog = try Catalog.load()
        let areas = catalog.pieces.map(\.area)
        #expect(areas.filter { $0 == "大沼" }.count == 4)
        #expect(areas.filter { $0 == "北斗" }.count == 4)
        #expect(areas.filter { $0 != "大沼" && $0 != "北斗" }.count == 24)
        #expect(Set(catalog.pieces.map(\.name)).count == catalog.pieces.count)
    }

    /// 元アプリの 2 件のピースは、id・画像を変えない
    @Test
    func keepsOriginalPieces() throws {
        let catalog = try Catalog.load()
        #expect(catalog.piece(id: 0)?.name == "元町公園")
        #expect(catalog.piece(id: 0)?.image == "piece14")
        #expect(catalog.piece(id: 1)?.name == "函館山")
        #expect(catalog.piece(id: 1)?.image == "piece1")
    }

    /// 今のなぞなぞ 1 問目の答え（五稜郭タワー）が、ピースの 1 つにある
    @Test
    func includesGoryokakuTower() throws {
        let catalog = try Catalog.load()
        #expect(catalog.pieces.contains { $0.name == "五稜郭タワー" })
    }

    /// ピースは文字列の緯度・経度を数値に直して読む
    @Test
    func decodesPiecesWithNumericCoordinates() throws {
        let catalog = try Catalog.load()
        let piece = try #require(catalog.piece(id: 0))
        #expect(piece.name == "元町公園")
        #expect(piece.area == "元町・函館山")
        #expect(piece.image == "piece14")
        #expect(piece.latitude == 41.794689)
        #expect(piece.longitude == 140.754003)
    }

    /// なぞなぞのタイトル・問題文・ヒントを読む（末尾のカンマを直した riddles.json）
    @Test
    func decodesRiddles() throws {
        let catalog = try Catalog.load()
        #expect(catalog.riddles.map(\.title) == ["函館ののっぽ", "函館の見晴らし台"])
        #expect(catalog.riddles.first?.content == "函館の白くて高いものといえば？")
        #expect(catalog.riddles.first?.hint == "五◯郭タワー")
    }

    /// ピースの番号は画像の名前の末尾の数字
    @Test(arguments: [
        ("piece14", 14),
        ("piece1", 1),
        ("piece32", 32)
    ])
    func pieceNumberComesFromImageName(image: String, number: Int) {
        let piece = Piece(id: 0, name: "", latitude: 0, longitude: 0, area: "", image: image)
        #expect(piece.number == number)
    }

    /// 画像の名前に数字が無ければ、ピースの番号は無い
    @Test
    func pieceNumberIsNilWithoutDigits() {
        let piece = Piece(id: 0, name: "", latitude: 0, longitude: 0, area: "", image: "piece")
        #expect(piece.number == nil)
    }

    /// 同梱データのピースの番号（元町公園 → 14、函館山 → 1）
    @Test
    func bundledPieceNumbers() throws {
        let catalog = try Catalog.load()
        #expect(catalog.piece(id: 0)?.number == 14)
        #expect(catalog.piece(id: 1)?.number == 1)
    }

    /// ビーコンの UUID・major・minor から、`beaconId` と同じ id のピースを引く
    @Test
    func findsPieceForBeacon() throws {
        let catalog = try Catalog.load()
        #expect(catalog.piece(forBeaconUUID: beaconUUID, major: 0, minor: 5000)?.name == "元町公園")
        #expect(catalog.piece(forBeaconUUID: beaconUUID, major: 0, minor: 6000)?.name == "函館山")
    }

    /// 同梱データに無いビーコン（minor・major・UUID のどれかが違う）からはピースを引かない
    @Test
    func ignoresUnknownBeacon() throws {
        let catalog = try Catalog.load()
        #expect(catalog.piece(forBeaconUUID: beaconUUID, major: 0, minor: 4000) == nil)
        #expect(catalog.piece(forBeaconUUID: beaconUUID, major: 1, minor: 5000) == nil)
        #expect(catalog.piece(forBeaconUUID: UUID(), major: 0, minor: 5000) == nil)
    }

    /// ビーコンに対応するピースが無ければ `nil`
    @Test
    func returnsNilWhenBeaconHasNoPiece() {
        let catalog = Catalog(
            beacons: [Beacon(beaconId: 9, uuid: beaconUUID, major: 0, minor: 5000)],
            pieces: [],
            riddles: []
        )
        #expect(catalog.piece(forBeaconUUID: beaconUUID, major: 0, minor: 5000) == nil)
    }

    /// 緯度・経度が数値として読めないピースは、読み込みのエラーにする
    @Test
    func rejectsNonNumericCoordinate() {
        let json = Data("""
        {"id": 0, "name": "x", "latitude": "north", "longitude": "140.0", "area": "y", "image": "piece1"}
        """.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Piece.self, from: json)
        }
    }

    /// JSON が無いバンドルからは、無いファイルの名前つきのエラーで失敗する
    @Test
    func failsWhenResourceIsMissing() {
        #expect(throws: Catalog.LoadError.missingResource("beacons.json")) {
            try Catalog.load(from: Bundle(for: TestBundleToken.self))
        }
    }
}
