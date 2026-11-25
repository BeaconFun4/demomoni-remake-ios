//
//  PieceFlipCard.swift
//  demomoni-remake-ios
//

import SwiftUI

/// ピースをうらがえすときの見え方。回している角度（0 = 表、180 = 裏）から決める
nonisolated enum PieceFlip {
    /// 見えている面
    enum Face: Equatable {
        case front
        case back
    }

    /// 回している角度で見えている面。真横（90 度）を越えたら裏
    static func visibleFace(at angle: Double) -> Face {
        angle < 90 ? .front : .back
    }

    /// 回さずにフェードで入れ替えるとき（視差効果を減らす設定）の、表の不透明度。裏は 1 から引いた値
    static func frontOpacity(at angle: Double) -> Double {
        min(max(1 - angle / 180, 0), 1)
    }

    /// 回している途中の大きさ（裏の大きさに対する割合）。表（`frontScale`）から裏（1）へ、角度に合わせて少しずつ大きくする
    /// （裏は描き込めるよう表より大きく出すので、真横で急に大きさが変わらないようにする）
    static func scale(at angle: Double, frontScale: Double) -> Double {
        let progress = min(max(angle / 180, 0), 1)
        return frontScale + (1 - frontScale) * progress
    }
}

/// ピースの表と裏。`showsBack` が変わると縦の軸でくるっと回してうらがえす。
/// 裏は描き込めるよう大きく出す: 置き場所の 1 辺を裏の大きさ（`PieceBackLayout.backSide`）にし、表は今までの大きさ（`PieceBackLayout.frontSide`）に縮めて出す。
/// 視差効果を減らす設定（Reduce Motion）がオンなら、回さず・大きさも動かさずに、フェードで入れ替える
struct PieceFlipCard<Front: View, Back: View>: View {
    let showsBack: Bool
    let front: Front
    let back: Back

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(showsBack: Bool, @ViewBuilder front: () -> Front, @ViewBuilder back: () -> Back) {
        self.showsBack = showsBack
        self.front = front()
        self.back = back()
    }

    var body: some View {
        GeometryReader { proxy in
            let side = proxy.size.width
            PieceFlipRotation(
                angle: showsBack ? 180 : 0,
                rotates: !reduceMotion,
                frontScale: side > 0 ? PieceBackLayout.frontSide(backSide: side) / side : 1,
                front: front,
                back: back
            )
            .animation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(duration: 0.6), value: showsBack)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// 角度を動かしながら（`Animatable`）表と裏を描く。見えていない面は読み上げず、押せないようにする
private struct PieceFlipRotation<Front: View, Back: View>: View, Animatable {
    var angle: Double
    let rotates: Bool
    /// 表の大きさ（置き場所の 1 辺に対する割合）
    let frontScale: Double
    let front: Front
    let back: Back

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        let face = PieceFlip.visibleFace(at: angle)
        let frontOpacity = rotates ? (face == .front ? 1 : 0) : PieceFlip.frontOpacity(at: angle)
        ZStack {
            front
                // 回さないときは、表をいつも今までの大きさで出す
                .scaleEffect(rotates ? 1 : frontScale)
                .opacity(frontOpacity)
                .accessibilityHidden(face != .front)
                .allowsHitTesting(face == .front)
            back
                // 裏は全体と一緒に 180 度回ると左右が反転して見えるので、先に反対へ回しておく
                .rotation3DEffect(.degrees(rotates ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                .opacity(1 - frontOpacity)
                .accessibilityHidden(face != .back)
                .allowsHitTesting(face == .back)
        }
        // 回すときは、表の大きさから裏の大きさへ、回しながら大きくする
        .scaleEffect(rotates ? PieceFlip.scale(at: angle, frontScale: frontScale) : 1)
        .rotation3DEffect(.degrees(rotates ? angle : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
    }
}
