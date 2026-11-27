//
//  PieceAcquisitionTests.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import Testing

struct PieceAcquisitionTests {
    private let station = Piece(id: 11, name: "函館駅", latitude: 0, longitude: 0, area: "函館駅前", image: "piece11")
    private let market = Piece(id: 10, name: "函館朝市", latitude: 0, longitude: 0, area: "函館駅前", image: "piece10")

    /// 範囲に入ったピースのうち、まだ獲得していないいちばん近いものを「ゲットした」画面に出す
    @Test
    func nearestNewPieceIsShown() {
        #expect(PieceAcquisition.newPiece(detected: [station, market], collectedPieceIDs: []) == station)
        #expect(PieceAcquisition.newPiece(detected: [station, market], collectedPieceIDs: [1]) == station)
    }

    /// 範囲が重なっていて、近いほうを獲得済みなら、次に近いものを出す（1 つずつゲットする）
    @Test
    func skipsCollectedPiece() {
        #expect(PieceAcquisition.newPiece(detected: [station, market], collectedPieceIDs: [11]) == market)
    }

    /// 範囲に入ったピースをすべて獲得済みなら、「ゲットした」画面に出さない
    @Test
    func collectedPiecesAreNotShownAgain() {
        #expect(PieceAcquisition.newPiece(detected: [station], collectedPieceIDs: [11]) == nil)
        #expect(PieceAcquisition.newPiece(detected: [station, market], collectedPieceIDs: [10, 11]) == nil)
    }

    /// どのピースの範囲にも入っていなければ出さない
    @Test
    func nothingDetected() {
        #expect(PieceAcquisition.newPiece(detected: [], collectedPieceIDs: []) == nil)
    }
}
