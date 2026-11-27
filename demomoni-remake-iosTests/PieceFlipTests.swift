//
//  PieceFlipTests.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import Testing

/// ピースをうらがえすときの見え方と、裏側の文言
struct PieceFlipTests {
    /// 真横（90 度）までは表、越えたら裏が見える
    @Test(arguments: [
        (0.0, PieceFlip.Face.front),
        (89.9, .front),
        (90, .back),
        (180, .back)
    ])
    func visibleFace(angle: Double, expected: PieceFlip.Face) {
        #expect(PieceFlip.visibleFace(at: angle) == expected)
    }

    /// 回さずに入れ替えるときは、表が少しずつ消えて裏が出る。範囲の外の角度でも 0〜1 に収める
    @Test(arguments: [(0.0, 1.0), (90, 0.5), (180, 0), (-10, 1), (200, 0)])
    func frontOpacity(angle: Double, expected: Double) {
        #expect(PieceFlip.frontOpacity(at: angle) == expected)
    }

    /// 回しながら、表の大きさから裏の大きさへ少しずつ大きくする（真横で急に変わらない）。範囲の外の角度でも表と裏の間に収める
    @Test(arguments: [(0.0, 0.8), (90, 0.9), (180, 1.0), (-10, 0.8), (200, 1.0)])
    func scaleGrowsTowardBack(angle: Double, expected: Double) {
        #expect(abs(PieceFlip.scale(at: angle, frontScale: 0.8) - expected) < 0.0001)
    }

    /// 裏側の読み上げは、写真があるか・手書きしたかで変える
    @Test
    func backLabel() {
        #expect(PiecePhotoText.backLabel(hasPhoto: false, hasDrawing: false) == "ピースのうら、しゃしんはまだないよ")
        #expect(PiecePhotoText.backLabel(hasPhoto: false, hasDrawing: true) == "ピースのうら、しゃしんはまだないよ")
        #expect(PiecePhotoText.backLabel(hasPhoto: true, hasDrawing: false) == "ピースのうらのしゃしん")
        #expect(PiecePhotoText.backLabel(hasPhoto: true, hasDrawing: true) == "かきこんだピースのうらのしゃしん")
    }
}
