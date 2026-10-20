//
//  SignatureDrawingTests.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import Foundation
import PencilKit
import Testing

struct SignatureDrawingTests {
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
