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
}

/// ピースの表と裏。`showsBack` が変わると縦の軸で回してうらがえす。
/// 視差効果を減らす設定（Reduce Motion）がオンなら、回さずにフェードで入れ替える
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
        PieceFlipRotation(angle: showsBack ? 180 : 0, rotates: !reduceMotion, front: front, back: back)
            .animation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(duration: 0.6), value: showsBack)
    }
}

/// 角度を動かしながら（`Animatable`）表と裏を描く。見えていない面は読み上げず、押せないようにする
private struct PieceFlipRotation<Front: View, Back: View>: View, Animatable {
    var angle: Double
    let rotates: Bool
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
        .rotation3DEffect(.degrees(rotates ? angle : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
    }
}
