//
//  GIFAnimationTests.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import Foundation
import Testing
import UIKit

struct GIFAnimationTests {
    /// 歩くうさぎの GIF（dataset）をアセットカタログから読め、フレームが複数ある
    @Test
    func loadsWalkingRabbitFromAssetCatalog() throws {
        let asset = try #require(NSDataAsset(name: "tekuusa"))
        let animation = try #require(GIFAnimation(data: asset.data))
        #expect(animation.frames.count == 8)
        #expect(animation.durations.count == animation.frames.count)
        #expect(animation.durations.allSatisfy { $0 > 0 })
    }

    /// GIF でないデータは読まない
    @Test
    func rejectsNonGIFData() {
        #expect(GIFAnimation(data: Data("not a gif".utf8)) == nil)
    }

    /// 経過時間から、そのとき出すフレームの番号を選ぶ
    @Test(arguments: [
        (0.0, 0),
        (0.05, 0),
        (0.1, 1),
        (0.25, 1),
        (0.31, 2),
        (0.59, 2)
    ])
    func frameIndexFollowsDurations(elapsed: TimeInterval, index: Int) {
        #expect(GIFAnimation.frameIndex(at: elapsed, durations: [0.1, 0.2, 0.3]) == index)
    }

    /// 1 周したら最初のフレームに戻る（繰り返し再生する）
    @Test
    func frameIndexLoops() {
        #expect(GIFAnimation.frameIndex(at: 0.61, durations: [0.1, 0.2, 0.3]) == 0)
        #expect(GIFAnimation.frameIndex(at: 0.75, durations: [0.1, 0.2, 0.3]) == 1)
    }

    /// 秒数が 0 のときは最初のフレームのまま
    @Test
    func frameIndexWithZeroDurations() {
        #expect(GIFAnimation.frameIndex(at: 1, durations: [0, 0]) == 0)
    }
}
