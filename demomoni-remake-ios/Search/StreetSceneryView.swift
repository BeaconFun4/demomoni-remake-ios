//
//  StreetSceneryView.swift
//  demomoni-remake-ios
//

import SwiftUI

/// 歩くうさぎの景色（街路樹・建物・雲）。手前から奥へ遠ざかり、奥で消えたら手前から出てくる。
/// 道の画像（正方形）と同じ枠に重ねる。並びの計算は `StreetScenery`。
/// 視差効果を減らす（Reduce Motion）が有効なときは、止まった並びを出す
struct StreetSceneryView: View {
    /// 木の色（テーマカラーに緑が無いので、ここで決める）
    static let treeColor = Color(red: 0.45, green: 0.73, blue: 0.42)
    /// 建物の色（水色の背景の上で、遠くに霞んで見える色）
    static let buildingColor = Color(red: 0.55, green: 0.72, blue: 0.84)
    /// 雲の色
    static let cloudColor = Color.white.opacity(0.9)

    /// 描く層。先の層から順に描き、後の層を上に重ねる
    let layers: [StreetScenery.Layer]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 動き始めた時刻。画面に出るたびに最初の並びから動かす
    @State private var startDate = Date.now

    var body: some View {
        GeometryReader { proxy in
            let side = proxy.size.width
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
                let elapsed = reduceMotion ? 0 : context.date.timeIntervalSince(startDate)
                ZStack {
                    ForEach(layers.indices, id: \.self) { layerIndex in
                        let layer = layers[layerIndex]
                        // 奥のものから順に描き、手前のものを上に重ねる
                        ForEach(StreetScenery.items(of: layer, at: elapsed)) { item in
                            let height = item.height * side
                            Image(systemName: Self.symbolName(of: layer.kind))
                                .resizable()
                                .scaledToFit()
                                .frame(height: height)
                                .foregroundStyle(Self.color(of: layer.kind))
                                .opacity(item.opacity)
                                // 下の中央を計算した位置に合わせる
                                .position(x: item.position.x * side, y: item.position.y * side - height / 2)
                        }
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

    /// 景色の種類ごとの SF Symbols の名前
    static func symbolName(of kind: StreetScenery.Kind) -> String {
        switch kind {
        case .tree:
            "tree.fill"
        case .building:
            "building.2.fill"
        case .cloud:
            "cloud.fill"
        }
    }

    /// 景色の種類ごとの色
    static func color(of kind: StreetScenery.Kind) -> Color {
        switch kind {
        case .tree:
            treeColor
        case .building:
            buildingColor
        case .cloud:
            cloudColor
        }
    }
}
