//
//  StreetScenery.swift
//  demomoni-remake-ios
//

import CoreGraphics
import Foundation

/// さがすタブの歩くうさぎの景色（道の両側の街路樹）の並び。
/// 座標は道の画像（`way.png`。正方形）の枠に対する割合（左上が 0、右下が 1）で表す。
///
/// うさぎは正面（こちら）を向いて歩くので、木は道の手前（画面の下・大きい）から奥（消失点・小さい）へ遠ざかり、
/// 奥で消えたら手前に戻って繰り返す。木は道に沿った距離で等間隔に並べ、等速で動かす。
/// 画面上の位置と大きさは遠近法で決める（距離 `z` のものは、手前の端からの見かけの大きさが `nearDistance / z` 倍になる）
nonisolated enum StreetScenery {
    /// 道のどちら側か
    enum Side: CaseIterable, Sendable {
        case left
        case right
    }

    /// 1 本の木
    struct Tree: Equatable, Identifiable, Sendable {
        /// 道のどちら側か
        let side: Side
        /// その側の何本目か（並びの中で変わらない番号。View の識別に使う）
        let index: Int
        /// 奥行きの進み具合（0 = 手前の端、1 = 奥の端）
        let progress: Double
        /// 木の根元（下の中央）の位置
        let position: CGPoint
        /// 木の高さ（道の画像の 1 辺に対する割合）
        let height: Double
        /// 不透明度（手前の端で現れ、奥の端の手前で消える）
        let opacity: Double

        /// 並びの中で変わらない識別子
        var id: String {
            "\(side)-\(index)"
        }
    }

    // MARK: - 道の画像の寸法（way.png を測った値）

    /// 道の消失点（左右の縁を延ばして交わるところ）
    static let vanishingPoint = CGPoint(x: 0.457, y: 0.328)
    /// 道の下端の高さ
    static let roadBottomY = 0.66
    /// 道の下端の高さでの、左の縁の x
    static let roadLeftEdgeBottomX = 0.033
    /// 道の下端の高さでの、右の縁の x（画像の右端より外まで延ばした値）
    static let roadRightEdgeBottomX = 1.133

    // MARK: - 見え方（実機で見ながら調整する）

    /// 木の向き。1 = 手前から奥へ遠ざかる、-1 = 奥から手前へ近づく
    static let direction: Double = 1
    /// 片側の木の本数
    static let treesPerSide = 6
    /// 隣り合う木の間隔（道に沿った距離。手前の端までの距離 `nearDistance` を 1 とする）
    static let spacing = 1.5
    /// 手前の端までの距離
    static let nearDistance = 1.0
    /// 木が進む速さ（道に沿った距離 / 秒）
    static let speed = 0.75
    /// 道の縁から木の根元までの幅（道の下端の高さでの、道の画像の 1 辺に対する割合）
    static let treeMargin = 0.1
    /// 手前の端での木の高さ（道の画像の 1 辺に対する割合）
    static let nearTreeHeight = 0.3
    /// 手前の端で現れるまでの長さ（奥行きの進み具合の割合）
    static let fadeInLength = 0.08
    /// 奥の端で消えるまでの長さ（奥行きの進み具合の割合）
    static let fadeOutLength = 0.3

    /// 1 本の木が手前の端から奥の端まで進む距離
    static var depthLength: Double {
        Double(treesPerSide) * spacing
    }

    /// 並びが元に戻るまでの秒数
    static var period: TimeInterval {
        depthLength / speed
    }

    /// 経過時間 `elapsed` 秒のときの木の並び。奥の木から順に並べる（この順に描けば手前の木が上に重なる）。
    /// Reduce Motion のときは時刻を固定して呼ぶ（止まった並び）。`direction` は向き（既定は `StreetScenery.direction`）
    static func trees(at elapsed: TimeInterval, direction: Double = StreetScenery.direction) -> [Tree] {
        let travelled = direction * elapsed * speed / depthLength
        let trees = Side.allCases.flatMap { side in
            (0..<treesPerSide).map { index in
                // 右側は半分ずらして、左右の木が同じ高さに並ばないようにする
                let stagger = side == .right ? 0.5 : 0
                let progress = fraction((Double(index) + stagger) / Double(treesPerSide) + travelled)
                return tree(side: side, index: index, progress: progress)
            }
        }
        return trees.sorted { $0.progress > $1.progress }
    }

    /// 奥行きの進み具合 `progress` にある木
    static func tree(side: Side, index: Int, progress: Double) -> Tree {
        let scale = perspectiveScale(progress: progress)
        let bottomX = switch side {
        case .left:
            roadLeftEdgeBottomX - treeMargin
        case .right:
            roadRightEdgeBottomX + treeMargin
        }
        return Tree(
            side: side,
            index: index,
            progress: progress,
            position: groundPoint(scale: scale, bottomX: bottomX),
            height: nearTreeHeight * scale,
            opacity: opacity(progress: progress)
        )
    }

    /// 奥行きの進み具合 `progress` にあるものの、手前の端に対する見かけの大きさ（1 = 手前の端、奥ほど 0 に近づく）
    static func perspectiveScale(progress: Double) -> Double {
        nearDistance / (nearDistance + progress * depthLength)
    }

    /// 道の下端の高さで x = `bottomX` を通り、消失点へ向かう線の上で、見かけの大きさが `scale` の地面の点
    static func groundPoint(scale: Double, bottomX: Double) -> CGPoint {
        CGPoint(
            x: vanishingPoint.x + scale * (bottomX - vanishingPoint.x),
            y: vanishingPoint.y + scale * (roadBottomY - vanishingPoint.y)
        )
    }

    /// 高さ `y` での道の縁の x
    static func roadEdgeX(side: Side, y: Double) -> Double {
        let scale = (y - vanishingPoint.y) / (roadBottomY - vanishingPoint.y)
        let bottomX = side == .left ? roadLeftEdgeBottomX : roadRightEdgeBottomX
        return groundPoint(scale: scale, bottomX: bottomX).x
    }

    /// 奥行きの進み具合 `progress` での不透明度。手前の端で現れ、奥の端に近づくと消える
    static func opacity(progress: Double) -> Double {
        min(1, progress / fadeInLength, (1 - progress) / fadeOutLength)
    }

    /// 小数部分（0 以上 1 未満）。負の数も 0〜1 に収める
    static func fraction(_ value: Double) -> Double {
        let fraction = value - value.rounded(.down)
        // ごく小さい負の数は、丸めで 1 になる
        return fraction < 1 ? fraction : 0
    }
}
