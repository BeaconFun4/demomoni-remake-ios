//
//  StreetTreesView.swift
//  demomoni-remake-ios
//

import SwiftUI

/// 歩くうさぎの道の両側に並ぶ街路樹。道の手前から奥へ遠ざかり、奥で消えたら手前から出てくる。
/// 道の画像（正方形）と同じ枠に重ねる。並びの計算は `StreetScenery`。
/// 視差効果を減らす（Reduce Motion）が有効なときは、止まった並びを出す
struct StreetTreesView: View {
    /// 木の色（テーマカラーに緑が無いので、ここで決める）
    static let treeColor = Color(red: 0.45, green: 0.73, blue: 0.42)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 動き始めた時刻。画面に出るたびに最初の並びから動かす
    @State private var startDate = Date.now

    var body: some View {
        GeometryReader { proxy in
            let side = proxy.size.width
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
                let elapsed = reduceMotion ? 0 : context.date.timeIntervalSince(startDate)
                ZStack {
                    // 奥の木から順に描き、手前の木を上に重ねる
                    ForEach(StreetScenery.trees(at: elapsed)) { tree in
                        let height = tree.height * side
                        Image(systemName: "tree.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(height: height)
                            .foregroundStyle(Self.treeColor)
                            .opacity(tree.opacity)
                            // 根元（下の中央）を計算した位置に合わせる
                            .position(x: tree.position.x * side, y: tree.position.y * side - height / 2)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            startDate = .now
        }
    }
}
