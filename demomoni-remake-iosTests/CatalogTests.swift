//
//  CatalogTests.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import Foundation
import Testing

/// テストのバンドル（同梱データの JSON が入っていない）を指すための型
private final class TestBundleToken {}

struct CatalogTests {
    private let beaconUUID = UUID(uuidString: "E8C65602-6D9C-44EF-9734-B2D3EF1CD961")!

    /// 同梱した 3 つの JSON を読める。件数は元アプリのデータのまま 2 件ずつ
    @Test
    func loadsBundledData() throws {
        let catalog = try Catalog.load()
        #expect(catalog.beacons.count == 2)
        #expect(catalog.pieces.count == 2)
        #expect(catalog.riddles.count == 2)
    }

    /// ビーコンの UUID・major・minor を元のデータのとおりに読む
    @Test
    func decodesBeacons() throws {
        let catalog = try Catalog.load()
        #expect(catalog.beacons == [
            Beacon(beaconId: 0, uuid: beaconUUID, major: 0, minor: 5000),
            Beacon(beaconId: 1, uuid: beaconUUID, major: 0, minor: 6000)
        ])
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
        #expect(catalog.piece(forBeaconUUID: beaconUUID, major: 0, minor: 7000) == nil)
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
