//
//  PieceAcquisitionTests.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import Testing

struct PieceAcquisitionTests {
    private let motomachi = Piece(id: 0, name: "元町公園", latitude: 0, longitude: 0, area: "元町・函館山", image: "piece14")

    /// まだ獲得していないピースを見つけたら「ゲットした」画面に出す
    @Test
    func newPieceIsShown() {
        #expect(PieceAcquisition.newPiece(detected: motomachi, collectedPieceIDs: []) == motomachi)
        #expect(PieceAcquisition.newPiece(detected: motomachi, collectedPieceIDs: [1]) == motomachi)
    }

    /// 獲得済みのピースは、検知しても「ゲットした」画面に出さない
    @Test
    func collectedPieceIsNotShownAgain() {
        #expect(PieceAcquisition.newPiece(detected: motomachi, collectedPieceIDs: [0]) == nil)
    }

    /// 何も見つけていなければ出さない
    @Test
    func nothingDetected() {
        #expect(PieceAcquisition.newPiece(detected: nil, collectedPieceIDs: []) == nil)
    }
}
