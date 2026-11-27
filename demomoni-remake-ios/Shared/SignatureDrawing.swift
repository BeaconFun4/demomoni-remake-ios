//
//  SignatureDrawing.swift
//  demomoni-remake-ios
//

import PencilKit
import UIKit

/// ピースに重ねるサイン（`PKDrawing`）。ピースの裏側の写真の上の手書きにも使う。
/// 描く画面の大きさに関係なく、ピースの画像と同じ `canvasSide` × `canvasSide` の正方形の座標で保存する。
/// 画面には、その正方形のうち `visibleRect` の部分だけを出すこともできる（裏側はピースが入るまんなかを大きく出す。`PieceBackLayout`）
enum SignatureDrawing {
    /// サインの座標の広さ（ピースの画像の 400 × 400 と同じ）
    static let canvasSide: CGFloat = 400
    /// 保存する座標の正方形の全体
    static let fullRect = CGRect(x: 0, y: 0, width: canvasSide, height: canvasSide)

    /// 保存したサインのデータから、ピースの画像に重ねる画像を作る。データが壊れていれば `nil`。
    /// `PKDrawing` は外観に合わせてインクの色を変えるので、アプリと同じライトの外観で描く
    /// - Parameter rect: 画像にする範囲（保存する座標）。既定は正方形の全体
    static func image(from data: Data, rect: CGRect = fullRect, scale: CGFloat = 2) -> UIImage? {
        guard let drawing = try? PKDrawing(data: data) else {
            return nil
        }
        var image: UIImage?
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            image = drawing.image(from: rect, scale: scale)
        }
        return image
    }

    /// 1 辺 `side` の画面で描いたサインを、保存する座標（`canvasSide` の正方形）に直す
    /// - Parameter visibleRect: 画面に出している範囲（保存する座標）。画面の 1 辺がこの範囲の 1 辺に当たる
    static func normalized(_ drawing: PKDrawing, fromSide side: CGFloat, visibleRect: CGRect = fullRect) -> PKDrawing {
        let factor = visibleRect.width / side
        guard factor.isFinite, factor > 0 else {
            return drawing
        }
        // 縮めてから、出している範囲の左上へずらす
        return drawing.transformed(
            using: CGAffineTransform(translationX: visibleRect.minX, y: visibleRect.minY).scaledBy(x: factor, y: factor)
        )
    }

    /// 保存したサインを、1 辺 `side` の画面で描き足せる座標に直す
    /// - Parameter visibleRect: 画面に出している範囲（保存する座標）。画面の 1 辺がこの範囲の 1 辺に当たる
    static func denormalized(_ drawing: PKDrawing, toSide side: CGFloat, visibleRect: CGRect = fullRect) -> PKDrawing {
        let factor = side / visibleRect.width
        guard factor.isFinite, factor > 0 else {
            return drawing
        }
        // 出している範囲の左上を原点に戻してから、画面の大きさに広げる
        return drawing.transformed(
            using: CGAffineTransform(scaleX: factor, y: factor).translatedBy(x: -visibleRect.minX, y: -visibleRect.minY)
        )
    }
}
