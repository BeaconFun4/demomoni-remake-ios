//
//  SignatureDrawing.swift
//  demomoni-remake-ios
//

import PencilKit
import UIKit

/// ピースに重ねるサイン（`PKDrawing`）。
/// 描く画面の大きさに関係なく、ピースの画像と同じ `canvasSide` × `canvasSide` の正方形の座標で保存する
enum SignatureDrawing {
    /// サインの座標の広さ（ピースの画像の 400 × 400 と同じ）
    static let canvasSide: CGFloat = 400

    /// 保存したサインのデータから、ピースの画像に重ねる画像を作る。データが壊れていれば `nil`。
    /// `PKDrawing` は外観に合わせてインクの色を変えるので、アプリと同じライトの外観で描く
    static func image(from data: Data, scale: CGFloat = 2) -> UIImage? {
        guard let drawing = try? PKDrawing(data: data) else {
            return nil
        }
        var image: UIImage?
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            image = drawing.image(from: CGRect(x: 0, y: 0, width: canvasSide, height: canvasSide), scale: scale)
        }
        return image
    }

    /// 1 辺 `side` の画面で描いたサインを、保存する座標（`canvasSide` の正方形）に直す
    static func normalized(_ drawing: PKDrawing, fromSide side: CGFloat) -> PKDrawing {
        scaled(drawing, by: canvasSide / side)
    }

    /// 保存したサインを、1 辺 `side` の画面で描き足せる座標に直す
    static func denormalized(_ drawing: PKDrawing, toSide side: CGFloat) -> PKDrawing {
        scaled(drawing, by: side / canvasSide)
    }

    private static func scaled(_ drawing: PKDrawing, by factor: CGFloat) -> PKDrawing {
        guard factor.isFinite, factor > 0 else {
            return drawing
        }
        return drawing.transformed(using: CGAffineTransform(scaleX: factor, y: factor))
    }
}
