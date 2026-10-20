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

    /// 保存したサインのデータから、ピースの画像に重ねる画像を作る。データが壊れていれば `nil`
    static func image(from data: Data, scale: CGFloat = 2) -> UIImage? {
        guard let drawing = try? PKDrawing(data: data) else {
            return nil
        }
        return drawing.image(from: CGRect(x: 0, y: 0, width: canvasSide, height: canvasSide), scale: scale)
    }
}
