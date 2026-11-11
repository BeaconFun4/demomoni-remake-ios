//
//  PieceCountTests.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import Testing

struct PieceCountTests {
    private let pieces = Catalog.bundled.pieces

    /// 何も獲得していなければ 0 / 全部
    @Test
    func noneCollected() {
        let count = PieceCount(pieces: pieces, collectedPieceIDs: [Int]())
        #expect(count.collected == 0)
        #expect(count.total == 32)
        #expect(count.text == "0 / 32")
    }

    /// 一部を獲得していれば、その数を出す
    @Test
    func someCollected() {
        let count = PieceCount(pieces: pieces, collectedPieceIDs: [1, 14, 20])
        #expect(count.collected == 3)
        #expect(count.total == 32)
        #expect(count.text == "3 / 32")
    }

    /// 全部を獲得していれば 全部 / 全部
    @Test
    func allCollected() {
        let count = PieceCount(pieces: pieces, collectedPieceIDs: pieces.map(\.id))
        #expect(count.collected == count.total)
        #expect(count.text == "32 / 32")
    }

    /// 同梱に無い id の記録は数えない
    @Test
    func ignoresUnknownIDs() {
        let unknownID = (pieces.map(\.id).max() ?? 0) + 1
        let count = PieceCount(pieces: pieces, collectedPieceIDs: [1, unknownID, -1])
        #expect(count.collected == 1)
        #expect(count.text == "1 / 32")
    }

    /// 同じ id が重なった記録は 1 つと数える
    @Test
    func countsDuplicateIDsOnce() {
        let count = PieceCount(pieces: pieces, collectedPieceIDs: [1, 1, 14, 14, 14])
        #expect(count.collected == 2)
        #expect(count.text == "2 / 32")
    }

    /// 表示の文字と読み上げの形
    @Test
    func texts() {
        let count = PieceCount(pieces: Array(pieces.prefix(5)), collectedPieceIDs: [pieces[0].id])
        #expect(count.text == "1 / 5")
        #expect(count.accessibilityLabel == "ゲットしたピース 1 こ、全部で 5 こ")
    }
}
