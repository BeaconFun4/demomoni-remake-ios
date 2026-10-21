//
//  PieceBoardLayoutTests.swift
//  demomoni-remake-iosTests
//

import CoreGraphics
@testable import demomoni_remake_ios
import Testing
import UIKit

struct PieceBoardLayoutTests {
    /// ピース No.N は左上から行ごとに数えて N 番目のマス（4 列 × 8 行）
    @Test(arguments: [
        (1, CGRect(x: 0, y: 0, width: 0.25, height: 0.125)),
        (4, CGRect(x: 0.75, y: 0, width: 0.25, height: 0.125)),
        (5, CGRect(x: 0, y: 0.125, width: 0.25, height: 0.125)),
        (14, CGRect(x: 0.25, y: 0.375, width: 0.25, height: 0.125)),
        (32, CGRect(x: 0.75, y: 0.875, width: 0.25, height: 0.125))
    ])
    func unitCellFrame(number: Int, expected: CGRect) {
        #expect(PieceBoardLayout.unitCellFrame(number: number) == expected)
    }

    /// 1〜32 でない番号にはマスが無い
    @Test(arguments: [0, 33, -1])
    func numbersOutsideBoardHaveNoCell(number: Int) {
        #expect(PieceBoardLayout.unitCellFrame(number: number) == nil)
        #expect(PieceBoardLayout.pieceImageFrame(number: number, in: CGSize(width: 400, height: 800)) == nil)
    }

    /// ピースの画像はマスと同じ中心で、縦横 2 倍の大きさに置く（盤の大きさに比例する）
    @Test
    func pieceImageFrameIsTwiceTheCell() {
        // 400 × 800 の盤では 1 マスが 100 × 100。No.14 のマスは (100, 300)
        #expect(PieceBoardLayout.pieceImageFrame(number: 14, in: CGSize(width: 400, height: 800))
            == CGRect(x: 50, y: 250, width: 200, height: 200))
        // 盤が半分の大きさなら、位置と大きさも半分
        #expect(PieceBoardLayout.pieceImageFrame(number: 14, in: CGSize(width: 200, height: 400))
            == CGRect(x: 25, y: 125, width: 100, height: 100))
        // 左上の No.1 は、盤の外に半マスはみ出す（外側は透明）
        #expect(PieceBoardLayout.pieceImageFrame(number: 1, in: CGSize(width: 400, height: 800))
            == CGRect(x: -50, y: -50, width: 200, height: 200))
    }

    /// 盤の縦横比は元の画像（800 × 1600）と同じ
    @Test
    func aspectRatioMatchesImage() throws {
        let image = try #require(UIImage(named: "goryokaku_long_monochrome"))
        #expect(PieceBoardLayout.aspectRatio == image.size.width / image.size.height)
    }

    /// 盤のすべてのマスに、400 × 400 のピースの画像がある（scripts/make-piece-images.swift で goryokaku_long を切り出したもの）
    @Test(arguments: PieceBoardLayout.numbers)
    func everyCellHasPieceImage(number: Int) throws {
        let image = try #require(UIImage(named: "piece\(number)"))
        #expect(image.size == CGSize(width: 400, height: 400))
    }

    /// 同梱データのピースはすべて、盤の番号と画像のアセットを持つ
    @Test
    func bundledPiecesHaveNumberAndImage() {
        for piece in Catalog.bundled.pieces {
            #expect(piece.number.map(PieceBoardLayout.numbers.contains) == true, "\(piece.image) の番号")
            #expect(UIImage(named: piece.image) != nil, "\(piece.image) のアセット")
        }
    }
}
