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
    /// 同梱した 2 つの JSON を読める。ピース・なぞなぞは盤のマスと同じ 32 件
    @Test
    func loadsBundledData() throws {
        let catalog = try Catalog.load()
        #expect(catalog.pieces.count == 32)
        #expect(catalog.riddles.count == 32)
    }

    /// ピースの id は 0〜31 で重複しない（獲得状態・なぞなぞが id でピースを指す）
    @Test
    func pieceIDsAreUnique() throws {
        let catalog = try Catalog.load()
        let pieceIDs = catalog.pieces.map(\.id)
        #expect(Set(pieceIDs).count == pieceIDs.count, "ピースの id が重複している")
        #expect(Set(pieceIDs) == Set(0..<32))
    }

    /// ピースの場所（範囲の中心）は、函館・大沼・北斗の中にある（緯度・経度の取り違えや、桁の誤りが無い）
    @Test
    func pieceCoordinatesAreInHakodateRegion() throws {
        let catalog = try Catalog.load()
        for piece in catalog.pieces {
            #expect((41.7...42.1).contains(piece.latitude), "\(piece.name) の緯度 \(piece.latitude)")
            #expect((140.5...140.9).contains(piece.longitude), "\(piece.name) の経度 \(piece.longitude)")
        }
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

    /// 名所の配分は函館 24・大沼 4・北斗 4。函館のエリア名は決まった書き方だけを使い、名前は重複しない
    @Test
    func piecesAreSplitByRegion() throws {
        let catalog = try Catalog.load()
        let hakodateAreas: Set = ["五稜郭", "元町・函館山", "ベイエリア", "函館駅前", "大森浜", "湯の川"]
        let areas = catalog.pieces.map(\.area)
        #expect(areas.filter(hakodateAreas.contains).count == 24)
        #expect(areas.filter { $0 == "大沼" }.count == 4)
        #expect(areas.filter { $0 == "北斗" }.count == 4)
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
        #expect(piece.latitude == 41.765501)
        #expect(piece.longitude == 140.709514)
    }

    /// なぞなぞのタイトル・問題文・ヒント・答え・ピースを読む。元アプリの 2 問は文言を変えず、先頭に置く
    @Test
    func decodesRiddles() throws {
        let catalog = try Catalog.load()
        #expect(catalog.riddles.prefix(2).map(\.title) == ["函館ののっぽ", "函館の見晴らし台"])
        let first = try #require(catalog.riddles.first)
        #expect(first.content == "函館の白くて高いものといえば？")
        #expect(first.hint == "五◯郭タワー")
        #expect(first.answer == "五稜郭タワー")
        #expect(catalog.piece(for: first)?.name == "五稜郭タワー")
        let second = catalog.riddles[1]
        #expect(second.content == "函館で夜景が綺麗な有名なところといえば？")
        #expect(second.hint == "函◯山")
        #expect(catalog.piece(for: second)?.id == 1)
    }

    /// なぞなぞとピースは 1 対 1。pieceId はすべて実在するピースを指し、id とタイトルは重複しない
    @Test
    func riddlesAndPiecesCorrespondOneToOne() throws {
        let catalog = try Catalog.load()
        let pieceIDs = catalog.riddles.map(\.pieceId)
        #expect(Set(pieceIDs).count == pieceIDs.count, "同じピースを指すなぞなぞがある")
        #expect(Set(pieceIDs) == Set(catalog.pieces.map(\.id)))
        #expect(Set(catalog.riddles.map(\.id)).count == catalog.riddles.count)
        #expect(Set(catalog.riddles.map(\.title)).count == catalog.riddles.count)
    }

    /// 答えはピースの場所の名前で、ヒントは答えの 1 文字だけを「◯」で伏せたもの
    @Test
    func riddleAnswersMatchPiecesAndHints() throws {
        let catalog = try Catalog.load()
        for riddle in catalog.riddles {
            #expect(catalog.piece(for: riddle)?.name == riddle.answer, "なぞなぞ \(riddle.id) の答え")
            let hint = Array(riddle.hint)
            let answer = Array(riddle.answer)
            #expect(hint.count == answer.count, "なぞなぞ \(riddle.id) のヒントの長さ")
            let hidden = zip(hint, answer).filter { $0 != $1 }
            #expect(hidden.count == 1 && hidden.first?.0 == "◯", "なぞなぞ \(riddle.id) のヒント: \(riddle.hint)")
        }
    }

    /// なぞなぞの pieceId のピースが無ければ `nil`
    @Test
    func pieceForRiddleIsNilWhenMissing() throws {
        let riddle = Riddle(id: 0, pieceId: 99, title: "", content: "", hint: "", answer: "", area: "")
        #expect(try Catalog.load().piece(for: riddle) == nil)
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
        #expect(throws: Catalog.LoadError.missingResource("pieces.json")) {
            try Catalog.load(from: Bundle(for: TestBundleToken.self))
        }
    }
}
