//
//  PieceBackLayout.swift
//  demomoni-remake-ios
//

import CoreGraphics

/// ピース詳細の表と裏の大きさ。裏側は、ピースの画像（400 × 400）のうちピースが入るまんなか（`visibleRect`）だけを、
/// 画面の幅に合わせて大きく出す（写真を入れて描き込むので、表より大きくする）。座標は表と同じ 400 × 400 のまま
nonisolated enum PieceBackLayout {
    /// ピースの画像の 1 辺（サインと同じ座標の広さ）
    static let imageSide: CGFloat = 400
    /// どのピースも入る、画像のまんなかの正方形（400 × 400 の座標）。
    /// マス（まんなかの 200 × 200）から凸が 40 出るので、同梱の 32 枚の不透明な部分はすべて 60〜340 に収まる（`PieceBackLayoutTests`）
    static let visibleRect = CGRect(x: 60, y: 60, width: 280, height: 280)
    /// どのピースでも内側になる、まんなかの正方形（400 × 400 の座標）。マスの辺から凹みが 40 入っても届かない（`PieceBackLayoutTests`）
    static let innerRect = CGRect(x: 140, y: 140, width: 120, height: 120)
    /// 裏側の 1 辺の上限（iPad で大きくなりすぎないようにする）
    static let maximumBackSide: CGFloat = 560
    /// 画面の左右の余白（ピース詳細の `padding()` と同じ）
    static let horizontalMargin: CGFloat = 16

    /// 画像の全体を、`visibleRect` を画面いっぱいにするために拡大する倍率（400 ÷ 280）
    static var zoom: CGFloat {
        imageSide / visibleRect.width
    }

    /// 裏側の 1 辺に対する、どのピースでも内側になる正方形（`innerRect`）の 1 辺の割合（120 ÷ 280）
    static var innerFraction: CGFloat {
        innerRect.width / visibleRect.width
    }

    /// 裏側の 1 辺。画面の幅から左右の余白を引いた幅（上限 560）
    static func backSide(containerWidth: CGFloat) -> CGFloat {
        max(0, min(containerWidth - horizontalMargin * 2, maximumBackSide))
    }

    /// 表側（ピースの画像の全体）の 1 辺。今までと同じく画面の幅の 8 割（上限 400）。裏側の 1 辺から求める
    /// （裏側が上限より小さければ画面の幅は裏側 + 余白、上限なら画面の幅は 592 以上なので表は 400）
    static func frontSide(backSide: CGFloat) -> CGFloat {
        min((backSide + horizontalMargin * 2) * 0.8, imageSide)
    }
}
