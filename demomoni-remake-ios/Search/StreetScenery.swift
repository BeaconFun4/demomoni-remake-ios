//
//  StreetScenery.swift
//  demomoni-remake-ios
//

import CoreGraphics
import Foundation

/// さがすタブの歩くうさぎの景色（道の両側の街路樹・遠くの建物・空の雲）の並び。
/// 座標は道の画像（`way.png`。正方形）の枠に対する割合（左上が 0、右下が 1）で表す。
///
/// うさぎは正面（こちら）を向いて歩くので、景色は手前（大きい）から奥（消失点・小さい）へ遠ざかり、
/// 奥で消えたら手前に戻って繰り返す。景色は層（`Layer`）ごとに、道に沿った距離で等間隔に並べ、等速で動かす。
/// 画面上の位置と大きさは遠近法で決める（距離 `z` のものは、道の下端（距離 1）での見かけの大きさの `1 / z` 倍になり、
/// 消失点と距離 1 の点を結ぶ線の上に乗る）。遠くの層ほど遠くに置いてゆっくり動かすので、近くの木より遅く見える（視差）
nonisolated enum StreetScenery {
    /// 道のどちら側か
    enum Side: CaseIterable, Sendable {
        case left
        case right
    }

    /// 景色の種類
    enum Kind: Sendable {
        /// 道の両側の街路樹
        case tree
        /// 地平線の近くの建物
        case building
        /// 空の雲
        case cloud
    }

    /// 景色の 1 つの層（同じ種類のものを、左右に同じ間隔・同じ速さで並べる）
    struct Layer: Sendable {
        /// 景色の種類
        let kind: Kind
        /// 片側の数
        let countPerSide: Int
        /// 隣り合うものの間隔（道に沿った距離。道の下端までの距離を 1 とする）
        let spacing: Double
        /// 手前の端までの距離
        let nearDistance: Double
        /// 進む速さ（道に沿った距離 / 秒）
        let speed: Double
        /// 距離 1 での高さ y（地面なら道の下端。空なら画像の上より上の、負の値）
        let referenceY: Double
        /// 距離 1 での、左側の x
        let leftReferenceX: Double
        /// 距離 1 での、右側の x
        let rightReferenceX: Double
        /// 距離 1 での高さ（道の画像の 1 辺に対する割合）
        let referenceHeight: Double
        /// 手前の端で現れるまでの長さ（奥行きの進み具合の割合）
        let fadeInLength: Double
        /// 奥の端で消えるまでの長さ（奥行きの進み具合の割合）
        let fadeOutLength: Double

        /// 1 つのものが手前の端から奥の端まで進む距離
        var depthLength: Double {
            Double(countPerSide) * spacing
        }

        /// 並びが元に戻るまでの秒数
        var period: TimeInterval {
            depthLength / speed
        }

        /// 奥行きの進み具合 `progress` にあるものの、距離 1 に対する見かけの大きさ（奥ほど 0 に近づく）
        func perspectiveScale(progress: Double) -> Double {
            1 / (nearDistance + progress * depthLength)
        }

        /// 距離 1 での x
        func referenceX(side: Side) -> Double {
            side == .left ? leftReferenceX : rightReferenceX
        }

        /// 奥行きの進み具合 `progress` での不透明度。手前の端で現れ、奥の端に近づくと消える
        func opacity(progress: Double) -> Double {
            min(1, progress / fadeInLength, (1 - progress) / fadeOutLength)
        }
    }

    /// 景色の 1 つ（木・建物・雲）
    struct Item: Equatable, Identifiable, Sendable {
        /// 道のどちら側か
        let side: Side
        /// その側の何番目か（並びの中で変わらない番号。View の識別に使う）
        let index: Int
        /// 奥行きの進み具合（0 = 手前の端、1 = 奥の端）
        let progress: Double
        /// 下の中央の位置
        let position: CGPoint
        /// 高さ（道の画像の 1 辺に対する割合）
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

    /// 景色の向き。1 = 手前から奥へ遠ざかる、-1 = 奥から手前へ近づく
    static let direction: Double = 1

    /// 道の両側の街路樹。道の縁から 0.1 外側に、手前の端（道の下端）から並べる
    static let trees = Layer(
        kind: .tree,
        countPerSide: 6,
        spacing: 1.5,
        nearDistance: 1,
        speed: 0.75,
        referenceY: roadBottomY,
        leftReferenceX: roadLeftEdgeBottomX - 0.1,
        rightReferenceX: roadRightEdgeBottomX + 0.1,
        referenceHeight: 0.3,
        fadeInLength: 0.08,
        fadeOutLength: 0.3
    )

    /// 地平線の近くの建物。木より外側・遠くに置き、木よりゆっくり動かす
    static let buildings = Layer(
        kind: .building,
        countPerSide: 4,
        spacing: 2.5,
        nearDistance: 3,
        speed: 0.3,
        referenceY: roadBottomY,
        leftReferenceX: -0.6,
        rightReferenceX: 1.6,
        referenceHeight: 0.6,
        fadeInLength: 0.15,
        fadeOutLength: 0.4
    )

    /// 空の雲。空の高いところに置き、建物よりさらにゆっくり動かす
    static let clouds = Layer(
        kind: .cloud,
        countPerSide: 3,
        spacing: 3,
        nearDistance: 4,
        speed: 0.15,
        referenceY: -0.6,
        leftReferenceX: -0.8,
        rightReferenceX: 1.7,
        referenceHeight: 0.5,
        fadeInLength: 0.15,
        fadeOutLength: 0.4
    )

    /// 経過時間 `elapsed` 秒のときの層 `layer` の並び。奥のものから順に並べる（この順に描けば手前のものが上に重なる）。
    /// Reduce Motion のときは時刻を固定して呼ぶ（止まった並び）。`direction` は向き（既定は `StreetScenery.direction`）
    static func items(of layer: Layer, at elapsed: TimeInterval, direction: Double = StreetScenery.direction) -> [Item] {
        let travelled = direction * elapsed * layer.speed / layer.depthLength
        let items = Side.allCases.flatMap { side in
            (0..<layer.countPerSide).map { index in
                // 右側は半分ずらして、左右が同じ高さに並ばないようにする
                let stagger = side == .right ? 0.5 : 0
                let progress = fraction((Double(index) + stagger) / Double(layer.countPerSide) + travelled)
                return item(of: layer, side: side, index: index, progress: progress)
            }
        }
        return items.sorted { $0.progress > $1.progress }
    }

    /// 層 `layer` の、奥行きの進み具合 `progress` にあるもの
    static func item(of layer: Layer, side: Side, index: Int, progress: Double) -> Item {
        let scale = layer.perspectiveScale(progress: progress)
        return Item(
            side: side,
            index: index,
            progress: progress,
            position: point(scale: scale, referenceX: layer.referenceX(side: side), referenceY: layer.referenceY),
            height: layer.referenceHeight * scale,
            opacity: layer.opacity(progress: progress)
        )
    }

    /// 距離 1 で (`referenceX`, `referenceY`) を通り、消失点へ向かう線の上で、見かけの大きさが `scale` の点
    static func point(scale: Double, referenceX: Double, referenceY: Double) -> CGPoint {
        CGPoint(
            x: vanishingPoint.x + scale * (referenceX - vanishingPoint.x),
            y: vanishingPoint.y + scale * (referenceY - vanishingPoint.y)
        )
    }

    /// 高さ `y` での道の縁の x
    static func roadEdgeX(side: Side, y: Double) -> Double {
        let scale = (y - vanishingPoint.y) / (roadBottomY - vanishingPoint.y)
        let referenceX = side == .left ? roadLeftEdgeBottomX : roadRightEdgeBottomX
        return point(scale: scale, referenceX: referenceX, referenceY: roadBottomY).x
    }

    /// 小数部分（0 以上 1 未満）。負の数も 0〜1 に収める
    static func fraction(_ value: Double) -> Double {
        let fraction = value - value.rounded(.down)
        // ごく小さい負の数は、丸めで 1 になる
        return fraction < 1 ? fraction : 0
    }
}
