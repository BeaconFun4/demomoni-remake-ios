//
//  SignatureDrawingTests.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import Foundation
import PencilKit
import Testing

struct SignatureDrawingTests {
    /// (from) から (to) まで 1 本の線を引いたサイン
    private func line(from start: CGPoint, to end: CGPoint) -> PKDrawing {
        let points = [start, end].enumerated().map { index, location in
            PKStrokePoint(
                location: location,
                timeOffset: TimeInterval(index),
                size: CGSize(width: 10, height: 10),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: .pi / 2
            )
        }
        let path = PKStrokePath(controlPoints: points, creationDate: Date())
        return PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .black), path: path)])
    }

    /// 1 辺 200 の画面で描いたサインは、保存する座標（1 辺 400）では 2 倍の位置になる
    @Test
    func normalizesToCanvasSide() {
        let drawn = line(from: CGPoint(x: 50, y: 50), to: CGPoint(x: 150, y: 150))
        let saved = SignatureDrawing.normalized(drawn, fromSide: 200)
        let center = CGPoint(x: saved.bounds.midX, y: saved.bounds.midY)
        #expect(abs(center.x - 200) < 1)
        #expect(abs(center.y - 200) < 1)
    }

    /// 保存したサインを別の大きさの画面に置いて、また保存し直しても同じ位置に戻る
    @Test
    func roundTripsThroughAnotherSide() {
        let saved = line(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 300, y: 300))
        let onIPad = SignatureDrawing.denormalized(saved, toSide: 600)
        #expect(abs(onIPad.bounds.midX - 300) < 1)
        let resaved = SignatureDrawing.normalized(onIPad, fromSide: 600)
        #expect(abs(resaved.bounds.midX - saved.bounds.midX) < 1)
        #expect(abs(resaved.bounds.width - saved.bounds.width) < 1)
    }

    /// 1 辺が 0 のときは直さない（画面に出る前）
    @Test
    func ignoresZeroSide() {
        let saved = line(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 300, y: 300))
        #expect(SignatureDrawing.normalized(saved, fromSide: 0).bounds == saved.bounds)
    }

    /// 保存したサインのデータから、ピースの画像と同じ正方形の画像を作る
    @Test
    func rendersSavedDrawing() throws {
        let points = [CGPoint(x: 100, y: 100), CGPoint(x: 300, y: 300)].enumerated().map { index, location in
            PKStrokePoint(
                location: location,
                timeOffset: TimeInterval(index),
                size: CGSize(width: 10, height: 10),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: .pi / 2
            )
        }
        let stroke = PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: Date()))
        let data = PKDrawing(strokes: [stroke]).dataRepresentation()

        let image = try #require(SignatureDrawing.image(from: data, scale: 1))
        #expect(image.size == CGSize(width: SignatureDrawing.canvasSide, height: SignatureDrawing.canvasSide))
    }

    /// 壊れたデータからは画像を作らない
    @Test
    func rejectsBrokenData() {
        #expect(SignatureDrawing.image(from: Data("broken".utf8)) == nil)
    }
}
