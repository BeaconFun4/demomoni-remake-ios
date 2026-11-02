//
//  StreetSceneryTests.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import Foundation
import Testing

struct StreetSceneryTests {
    /// 並びを side と index で引けるようにする
    private func treesByID(at elapsed: TimeInterval, direction: Double = StreetScenery.direction) -> [String: StreetScenery.Tree] {
        Dictionary(uniqueKeysWithValues: StreetScenery.trees(at: elapsed, direction: direction).map { ($0.id, $0) })
    }

    /// 左右に決めた本数ずつ並ぶ
    @Test
    func placesTreesOnBothSides() {
        let trees = StreetScenery.trees(at: 0)
        #expect(trees.count(where: { $0.side == .left }) == StreetScenery.treesPerSide)
        #expect(trees.count(where: { $0.side == .right }) == StreetScenery.treesPerSide)
    }

    /// 周期ちょうどで同じ並びに戻る
    @Test(arguments: [0.0, 1.3, 7.9])
    func returnsToSameArrangementAfterPeriod(elapsed: TimeInterval) throws {
        let start = treesByID(at: elapsed)
        let later = treesByID(at: elapsed + StreetScenery.period)
        for (id, tree) in start {
            let other = try #require(later[id])
            #expect(abs(tree.progress - other.progress) < 1e-9)
            #expect(abs(tree.position.y - other.position.y) < 1e-9)
        }
    }

    /// 時間とともに奥へ進む（手前から奥へ遠ざかる）
    @Test
    func treesMoveAwayOverTime() throws {
        let start = treesByID(at: 0.5)
        let later = treesByID(at: 0.6)
        for (id, tree) in start where tree.progress < 0.9 {
            let other = try #require(later[id])
            #expect(other.progress > tree.progress)
            #expect(other.position.y < tree.position.y)
        }
    }

    /// 周期の境目でも、見えている木の位置は少しずつしか動かない。
    /// 端から端へ戻る木は、戻る前も後もほとんど見えていない。どちらの向きでも同じ
    @Test(arguments: [1.0, -1.0])
    func wrapsSeamlessly(direction: Double) throws {
        let step = 1.0 / 30
        // 1 フレームで進む奥行きの進み具合と、それに合わせたしきい値（定数を調整してもテストを直さずに済むようにする）
        let progressStep = step * StreetScenery.speed / StreetScenery.depthLength
        let opacityStep = progressStep / min(StreetScenery.fadeInLength, StreetScenery.fadeOutLength) + 1e-9
        let maxYStep = (StreetScenery.roadBottomY - StreetScenery.vanishingPoint.y)
            * StreetScenery.depthLength / StreetScenery.nearDistance * progressStep + 1e-9
        var time = 0.0
        while time < StreetScenery.period {
            let current = treesByID(at: time, direction: direction)
            let next = treesByID(at: time + step, direction: direction)
            for (id, tree) in current {
                let other = try #require(next[id])
                if abs(other.progress - tree.progress) > 0.5 {
                    // 端から端へ戻った
                    #expect(tree.opacity <= opacityStep)
                    #expect(other.opacity <= opacityStep)
                } else {
                    #expect(abs(other.opacity - tree.opacity) <= opacityStep)
                    #expect(abs(other.position.y - tree.position.y) <= maxYStep)
                }
            }
            time += step
        }
    }

    /// 同時に見える本数は、周期の中で変わらない
    @Test
    func visibleTreeCountStaysConstant() {
        let step = 1.0 / 30
        var counts: Set<Int> = []
        var time = step / 2
        while time < StreetScenery.period {
            counts.insert(StreetScenery.trees(at: time).count { $0.opacity > 0 })
            time += step
        }
        #expect(counts == [StreetScenery.treesPerSide * 2])
    }

    /// 向きを反転すると、奥から手前へ近づく
    @Test
    func reversedDirectionMovesTowardViewer() throws {
        let start = treesByID(at: 0.5, direction: -1)
        let later = treesByID(at: 0.6, direction: -1)
        for (id, tree) in start where tree.progress > 0.1 {
            let other = try #require(later[id])
            #expect(other.progress < tree.progress)
            #expect(other.position.y > tree.position.y)
        }
    }

    /// 小数部分は 0 以上 1 未満に収まる（ごく小さい負の数も）
    @Test(arguments: [0.0, 0.25, 1.0, 2.75, -0.25, -1e-20, -3.0])
    func fractionStaysInUnitRange(value: Double) {
        let fraction = StreetScenery.fraction(value)
        #expect(fraction >= 0)
        #expect(fraction < 1)
    }

    /// 奥へ行くほど小さく、消失点へ近づく
    @Test
    func shrinksTowardVanishingPoint() {
        let progresses = Array(stride(from: 0.0, to: 1.0, by: 0.1))
        let trees = progresses.map { StreetScenery.tree(side: .left, index: 0, progress: $0) }
        let vanishingPoint = StreetScenery.vanishingPoint
        for (near, far) in zip(trees, trees.dropFirst()) {
            #expect(far.height < near.height)
            #expect(far.position.y < near.position.y)
            #expect(far.position.y > vanishingPoint.y)
            let nearDistance = hypot(near.position.x - vanishingPoint.x, near.position.y - vanishingPoint.y)
            let farDistance = hypot(far.position.x - vanishingPoint.x, far.position.y - vanishingPoint.y)
            #expect(farDistance < nearDistance)
        }
    }

    /// 手前の端では道の下端の高さにあり、手前の端での大きさになる
    @Test
    func nearEndIsAtRoadBottom() {
        let tree = StreetScenery.tree(side: .right, index: 0, progress: 0)
        #expect(abs(tree.position.y - StreetScenery.roadBottomY) < 1e-9)
        #expect(abs(tree.height - StreetScenery.nearTreeHeight) < 1e-9)
    }

    /// 左の木は道の左の縁より左、右の木は右の縁より右にある
    @Test(arguments: [0.0, 2.2, 5.5])
    func treesStandOutsideRoad(elapsed: TimeInterval) {
        for tree in StreetScenery.trees(at: elapsed) {
            let edge = StreetScenery.roadEdgeX(side: tree.side, y: tree.position.y)
            switch tree.side {
            case .left:
                #expect(tree.position.x < edge)
            case .right:
                #expect(tree.position.x > edge)
            }
        }
    }

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

    /// 手前の端で現れ、奥の端で消える。途中は不透明
    @Test
    func fadesInAndOut() {
        #expect(StreetScenery.opacity(progress: 0) == 0)
        #expect(StreetScenery.opacity(progress: 0.5) == 1)
        #expect(StreetScenery.opacity(progress: 0.999) < 0.01)
    }

    /// 奥の木から順に並ぶ（この順に描けば手前の木が上に重なる）
    @Test
    func sortsFarTreesFirst() {
        let progresses = StreetScenery.trees(at: 3.1).map(\.progress)
        #expect(progresses == progresses.sorted(by: >))
    }
}
