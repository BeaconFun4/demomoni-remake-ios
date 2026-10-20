//
//  PieceBoardLayout.swift
//  demomoni-remake-ios
//

import CoreGraphics

/// いちらんの盤（五稜郭の画像を 4 列 × 8 行の 32 マスに分けたもの）の位置の計算。
/// ピース No.N は、左上から行ごとに数えて N 番目のマス（ピースの画像と色つきの `goryokaku_long` の画素を照らして確かめた）
nonisolated enum PieceBoardLayout {
    /// 列の数
    static let columns = 4
    /// 行の数
    static let rows = 8
    /// ピースの番号の範囲
    static let numbers = 1...(columns * rows)
    /// 盤の縦横比（幅 ÷ 高さ。元の画像は 800 × 1600）
    static let aspectRatio = CGFloat(columns) / CGFloat(rows)
    /// ピースの画像の、マスに対する大きさ。画像（400 × 400）の中央の 200 × 200 がマスで、外側に出っ張りが入る
    static let pieceImageScale: CGFloat = 2

    /// ピース No.`number` のマスの、盤の大きさを 1 としたときの位置。番号が 1〜32 でなければ `nil`
    static func unitCellFrame(number: Int) -> CGRect? {
        guard numbers.contains(number) else {
            return nil
        }
        let index = number - 1
        let width = 1 / CGFloat(columns)
        let height = 1 / CGFloat(rows)
        return CGRect(
            x: CGFloat(index % columns) * width,
            y: CGFloat(index / columns) * height,
            width: width,
            height: height
        )
    }

    /// 大きさ `size` の盤に、ピース No.`number` の画像を置く位置（マスと同じ中心で、縦横 2 倍）。番号が 1〜32 でなければ `nil`
    static func pieceImageFrame(number: Int, in size: CGSize) -> CGRect? {
        guard let unit = unitCellFrame(number: number) else {
            return nil
        }
        let cell = CGRect(
            x: unit.minX * size.width,
            y: unit.minY * size.height,
            width: unit.width * size.width,
            height: unit.height * size.height
        )
        let grow = (pieceImageScale - 1) / 2
        return cell.insetBy(dx: -cell.width * grow, dy: -cell.height * grow)
    }
}
