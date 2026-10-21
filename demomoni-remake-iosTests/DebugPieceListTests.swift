//
//  DebugPieceListTests.swift
//  demomoni-remake-iosTests
//

#if DEBUG
@testable import demomoni_remake_ios
import Testing

struct DebugPieceListTests {
    private func piece(id: Int, image: String) -> Piece {
        Piece(id: id, name: "ピース\(id)", latitude: 0, longitude: 0, area: "", image: image)
    }

    /// 盤の番号の順に並べ、番号の無いピースは最後に置く。獲得済みかを添える
    @Test
    func rowsAreSortedByBoardNumber() {
        let pieces = [
            piece(id: 0, image: "piece14"),
            piece(id: 1, image: "piece1"),
            piece(id: 2, image: "piece"),
            piece(id: 3, image: "piece2")
        ]
        let rows = DebugPieceList.rows(pieces: pieces, collectedPieceIDs: [0, 2])
        #expect(rows.map(\.piece.id) == [1, 3, 0, 2])
        #expect(rows.map(\.isCollected) == [false, false, true, true])
    }

    /// 行の名前は番号と場所の名前。番号が無ければ名前だけ
    @Test
    func rowTitleHasNumberAndName() {
        let pieces = [piece(id: 0, image: "piece14"), piece(id: 9, image: "piece")]
        let rows = DebugPieceList.rows(pieces: pieces, collectedPieceIDs: [])
        #expect(rows.map(\.title) == ["No.14 ピース0", "ピース9"])
    }

    /// 擬似検知で選べるのは、まだ獲得していないピースだけ（盤の番号の順）
    @Test
    func detectableRowsExcludeCollectedPieces() {
        let pieces = [piece(id: 0, image: "piece14"), piece(id: 1, image: "piece1"), piece(id: 2, image: "piece2")]
        let rows = DebugPieceList.detectableRows(pieces: pieces, collectedPieceIDs: [1])
        #expect(rows.map(\.piece.id) == [2, 0])
        #expect(rows.allSatisfy { !$0.isCollected })
        #expect(DebugPieceList.detectableRows(pieces: pieces, collectedPieceIDs: [0, 1, 2]).isEmpty)
    }

    /// 同梱データでは 32 行で、1 行目は No.1
    @Test
    func bundledPiecesMakeThirtyTwoRows() {
        let rows = DebugPieceList.rows(pieces: Catalog.bundled.pieces, collectedPieceIDs: [])
        #expect(rows.count == Catalog.bundled.pieces.count)
        #expect(rows.first?.title == "No.1 函館山")
    }
}
#endif
