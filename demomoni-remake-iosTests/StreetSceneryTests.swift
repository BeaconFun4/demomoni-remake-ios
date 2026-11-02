//
//  StreetSceneryTests.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import Foundation
import Testing

struct StreetSceneryTests {
    /// すべての層
    nonisolated static let layers: [StreetScenery.Layer] = [StreetScenery.trees, StreetScenery.buildings, StreetScenery.clouds]

    /// 並びを side と index で引けるようにする
    private func itemsByID(
        of layer: StreetScenery.Layer,
        at elapsed: TimeInterval,
        direction: Double = StreetScenery.direction
    ) -> [String: StreetScenery.Item] {
        Dictionary(uniqueKeysWithValues: StreetScenery.items(of: layer, at: elapsed, direction: direction).map { ($0.id, $0) })
    }

    /// 1 フレームでの y の動きの最大（進み具合 0 で最も速い）
    private func maxYStep(of layer: StreetScenery.Layer, progressStep: Double) -> Double {
        let near = StreetScenery.item(of: layer, side: .left, index: 0, progress: 0)
        let next = StreetScenery.item(of: layer, side: .left, index: 0, progress: progressStep)
        return abs(next.position.y - near.position.y) + 1e-9
    }

    // MARK: - すべての層に共通

    /// 左右に決めた数ずつ並ぶ
    @Test(arguments: layers)
    func placesItemsOnBothSides(layer: StreetScenery.Layer) {
        let items = StreetScenery.items(of: layer, at: 0)
        #expect(items.count(where: { $0.side == .left }) == layer.countPerSide)
        #expect(items.count(where: { $0.side == .right }) == layer.countPerSide)
    }

    /// 周期ちょうどで同じ並びに戻る
    @Test(arguments: layers, [0.0, 1.3, 7.9])
    func returnsToSameArrangementAfterPeriod(layer: StreetScenery.Layer, elapsed: TimeInterval) throws {
        let start = itemsByID(of: layer, at: elapsed)
        let later = itemsByID(of: layer, at: elapsed + layer.period)
        for (id, item) in start {
            let other = try #require(later[id])
            #expect(abs(item.progress - other.progress) < 1e-9)
            #expect(abs(item.position.y - other.position.y) < 1e-9)
        }
    }

    /// 時間とともに奥へ進み、消失点へ近づく（手前から奥へ遠ざかる）
    @Test(arguments: layers)
    func itemsMoveAwayOverTime(layer: StreetScenery.Layer) throws {
        let start = itemsByID(of: layer, at: 0.5)
        let later = itemsByID(of: layer, at: 0.6)
        let vanishingY = StreetScenery.vanishingPoint.y
        for (id, item) in start where item.progress < 0.9 {
            let other = try #require(later[id])
            #expect(other.progress > item.progress)
            #expect(abs(other.position.y - vanishingY) < abs(item.position.y - vanishingY))
        }
    }

    /// 周期の境目でも、見えているものの位置は少しずつしか動かない。
    /// 端から端へ戻るものは、戻る前も後もほとんど見えていない。どちらの向きでも同じ
    @Test(arguments: layers, [1.0, -1.0])
    func wrapsSeamlessly(layer: StreetScenery.Layer, direction: Double) throws {
        let step = 1.0 / 30
        // 1 フレームで進む奥行きの進み具合と、それに合わせたしきい値（定数を調整してもテストを直さずに済むようにする）
        let progressStep = step * layer.speed / layer.depthLength
        let opacityStep = progressStep / min(layer.fadeInLength, layer.fadeOutLength) + 1e-9
        let maxYStep = maxYStep(of: layer, progressStep: progressStep)
        var time = 0.0
        while time < layer.period {
            let current = itemsByID(of: layer, at: time, direction: direction)
            let next = itemsByID(of: layer, at: time + step, direction: direction)
            for (id, item) in current {
                let other = try #require(next[id])
                if abs(other.progress - item.progress) > 0.5 {
                    // 端から端へ戻った
                    #expect(item.opacity <= opacityStep)
                    #expect(other.opacity <= opacityStep)
                } else {
                    #expect(abs(other.opacity - item.opacity) <= opacityStep)
                    #expect(abs(other.position.y - item.position.y) <= maxYStep)
                }
            }
            time += step
        }
    }

    /// はっきり見えている数は、周期の中で片側 1 つまでしか変わらない（急に増えたり減ったりしない）
    @Test(arguments: layers)
    func visibleCountStaysSteady(layer: StreetScenery.Layer) {
        let step = 1.0 / 30
        for side in StreetScenery.Side.allCases {
            var counts: [Int] = []
            var time = 0.0
            while time < layer.period {
                counts.append(StreetScenery.items(of: layer, at: time).count { $0.side == side && $0.opacity > 0.5 })
                time += step
            }
            let lowest = counts.min() ?? 0
            let highest = counts.max() ?? 0
            #expect(lowest > 0)
            #expect(highest - lowest <= 1)
        }
    }

    /// 向きを反転すると、奥から手前へ近づく
    @Test(arguments: layers)
    func reversedDirectionMovesTowardViewer(layer: StreetScenery.Layer) throws {
        let start = itemsByID(of: layer, at: 0.5, direction: -1)
        let later = itemsByID(of: layer, at: 0.6, direction: -1)
        for (id, item) in start where item.progress > 0.1 {
            let other = try #require(later[id])
            #expect(other.progress < item.progress)
        }
    }

    /// 奥へ行くほど小さく、消失点へ近づく
    @Test(arguments: layers)
    func shrinksTowardVanishingPoint(layer: StreetScenery.Layer) {
        let progresses = Array(stride(from: 0.0, to: 1.0, by: 0.1))
        let items = progresses.map { StreetScenery.item(of: layer, side: .left, index: 0, progress: $0) }
        let vanishingPoint = StreetScenery.vanishingPoint
        for (near, far) in zip(items, items.dropFirst()) {
            #expect(far.height < near.height)
            let nearDistance = hypot(near.position.x - vanishingPoint.x, near.position.y - vanishingPoint.y)
            let farDistance = hypot(far.position.x - vanishingPoint.x, far.position.y - vanishingPoint.y)
            #expect(farDistance < nearDistance)
        }
    }

    /// 奥のものから順に並ぶ（この順に描けば手前のものが上に重なる）
    @Test(arguments: layers)
    func sortsFarItemsFirst(layer: StreetScenery.Layer) {
        let progresses = StreetScenery.items(of: layer, at: 3.1).map(\.progress)
        #expect(progresses == progresses.sorted(by: >))
    }

    /// 手前の端で現れ、奥の端で消える。途中は不透明
    @Test(arguments: layers)
    func fadesInAndOut(layer: StreetScenery.Layer) {
        #expect(layer.opacity(progress: 0) == 0)
        #expect(layer.opacity(progress: 0.5) == 1)
        #expect(layer.opacity(progress: 0.999) < 0.01)
    }

    // MARK: - 街路樹

    /// 手前の端では道の下端の高さにあり、手前の端での大きさになる
    @Test
    func treesNearEndIsAtRoadBottom() {
        let tree = StreetScenery.item(of: StreetScenery.trees, side: .right, index: 0, progress: 0)
        #expect(abs(tree.position.y - StreetScenery.roadBottomY) < 1e-9)
        #expect(abs(tree.height - StreetScenery.trees.referenceHeight) < 1e-9)
    }

    /// 左の木は道の左の縁より左、右の木は右の縁より右にある
    @Test(arguments: [0.0, 2.2, 5.5])
    func treesStandOutsideRoad(elapsed: TimeInterval) {
        for tree in StreetScenery.items(of: StreetScenery.trees, at: elapsed) {
            let edge = StreetScenery.roadEdgeX(side: tree.side, y: tree.position.y)
            switch tree.side {
            case .left:
                #expect(tree.position.x < edge)
            case .right:
                #expect(tree.position.x > edge)
            }
        }
    }

    // MARK: - 建物と雲

    /// 建物は道より外側の、地平線（消失点の高さ）の近くの地面に立つ
    @Test(arguments: [0.0, 4.0, 12.0])
    func buildingsStandNearHorizonOutsideRoad(elapsed: TimeInterval) {
        let horizon = StreetScenery.vanishingPoint.y
        for building in StreetScenery.items(of: StreetScenery.buildings, at: elapsed) {
            #expect(building.position.y > horizon)
            #expect(building.position.y < horizon + (StreetScenery.roadBottomY - horizon) / 2)
            let edge = StreetScenery.roadEdgeX(side: building.side, y: building.position.y)
            switch building.side {
            case .left:
                #expect(building.position.x < edge)
            case .right:
                #expect(building.position.x > edge)
            }
        }
    }

    /// 雲は地平線より上の空にある（雲の下端が消失点より上）
    @Test(arguments: [0.0, 9.0, 30.0])
    func cloudsFloatInSky(elapsed: TimeInterval) {
        for cloud in StreetScenery.items(of: StreetScenery.clouds, at: elapsed) {
            #expect(cloud.position.y < StreetScenery.vanishingPoint.y)
        }
    }

    /// 遠くのものほどゆっくり動く（視差）。画面の上で最も速いところでも、建物は木より、雲は建物より遅い
    @Test
    func fartherLayersMoveSlower() {
        let step = 1.0 / 30
        func fastestScreenStep(of layer: StreetScenery.Layer) -> Double {
            maxYStep(of: layer, progressStep: step * layer.speed / layer.depthLength)
        }
        let trees = fastestScreenStep(of: StreetScenery.trees)
        let buildings = fastestScreenStep(of: StreetScenery.buildings)
        let clouds = fastestScreenStep(of: StreetScenery.clouds)
        #expect(buildings < trees)
        #expect(clouds < buildings)
        #expect(StreetScenery.buildings.speed < StreetScenery.trees.speed)
        #expect(StreetScenery.clouds.speed < StreetScenery.buildings.speed)
    }

    // MARK: - 道と計算の部品

    /// 道の縁の式は、way.png を測った値と合う
    @Test(arguments: [
        (0.40, 0.365, 0.6025),
        (0.50, 0.2375, 0.8075),
        (0.58, 0.135, 0.97)
    ])
    func roadEdgesMatchImage(y: Double, left: Double, right: Double) {
        #expect(abs(StreetScenery.roadEdgeX(side: .left, y: y) - left) < 0.01)
        #expect(abs(StreetScenery.roadEdgeX(side: .right, y: y) - right) < 0.01)
    }

    /// 小数部分は 0 以上 1 未満に収まる（ごく小さい負の数も）
    @Test(arguments: [0.0, 0.25, 1.0, 2.75, -0.25, -1e-20, -3.0])
    func fractionStaysInUnitRange(value: Double) {
        let fraction = StreetScenery.fraction(value)
        #expect(fraction >= 0)
        #expect(fraction < 1)
    }
}
