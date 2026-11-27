//
//  SignatureCanvasControllerTests.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import Foundation
import PencilKit
import Testing

@MainActor
struct SignatureCanvasControllerTests {
    /// 保存する座標（1 辺 400）で (100, 100) から (300, 300) まで引いたサイン
    private var savedSignature: Data {
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
        let path = PKStrokePath(controlPoints: points, creationDate: Date())
        return PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .black), path: path)]).dataRepresentation()
    }

    /// 保存してあったサインは、画面の大きさが決まったときにその大きさに直して置く
    @Test
    func placesSavedSignatureAtCanvasSize() {
        let controller = SignatureCanvasController(signature: savedSignature)
        controller.layout(side: 200)
        #expect(abs(controller.canvasView.drawing.bounds.midX - 100) < 1)
    }

    /// 画面の大きさが変わっても、保存するサインは同じ座標になる
    @Test
    func keepsSignatureAcrossResize() throws {
        let controller = SignatureCanvasController(signature: savedSignature)
        controller.layout(side: 200)
        controller.layout(side: 600)
        #expect(abs(controller.canvasView.drawing.bounds.midX - 300) < 1)

        let data = try #require(controller.signatureData())
        let saved = try PKDrawing(data: data)
        #expect(abs(saved.bounds.midX - 200) < 1)
    }

    /// ぜんぶ消したら、保存するサインは無い（サインを消す）
    @Test
    func clearMakesSignatureEmpty() {
        let controller = SignatureCanvasController(signature: savedSignature)
        controller.layout(side: 400)
        controller.clear()
        #expect(controller.signatureData() == nil)
    }

    /// ぜんぶ消した後に「もどる！」で元に戻せる。取り消しの記録はこのキャンバスだけのもの
    @Test
    func undoRestoresClearedSignature() {
        let controller = SignatureCanvasController(signature: savedSignature)
        controller.layout(side: 400)
        controller.clear()
        controller.undo()
        #expect(controller.signatureData() != nil)

        let other = SignatureCanvasController(signature: nil)
        #expect(other.canvasView.undoManager !== controller.canvasView.undoManager)
        #expect(other.canvasView.undoManager?.canUndo == false)
    }

    /// 大きさが変わったら、前の大きさの座標の取り消しの記録は消す
    @Test
    func resizeClearsUndoHistory() {
        let controller = SignatureCanvasController(signature: savedSignature)
        controller.layout(side: 400)
        controller.clear()
        controller.layout(side: 300)
        #expect(controller.canvasView.undoManager?.canUndo == false)
    }

    /// 道具を選ぶ
    @Test
    func selectsTool() {
        let controller = SignatureCanvasController(signature: nil)
        #expect(controller.tool == .pen)
        controller.select(.eraser)
        #expect(controller.tool == .eraser)
        #expect(controller.canvasView.tool is PKEraserTool)
    }

    /// 描くところの読み上げは、サインと写真の上の手書きで分ける。写真の上の手書きも、サインと同じ座標で保存する
    @Test
    func usesAccessibilityLabelAndSameCoordinatesForPhotoDrawing() {
        #expect(SignatureCanvasController(signature: nil).canvasView.accessibilityLabel == "サインをかくところ")
        let controller = SignatureCanvasController(signature: savedSignature, accessibilityLabel: "しゃしんにかきこむところ")
        #expect(controller.canvasView.accessibilityLabel == "しゃしんにかきこむところ")
        controller.layout(side: 300)
        let data = controller.signatureData()
        let drawing = data.flatMap { try? PKDrawing(data: $0) }
        #expect(abs((drawing?.bounds.midX ?? 0) - 200) < 1)
    }

    /// ピースの裏側のように 400 × 400 の一部だけを出すときは、保存してあった手書きをその範囲に合わせて置き、保存し直しても同じ座標になる
    @Test
    func placesDrawingWithinVisibleRect() throws {
        let controller = SignatureCanvasController(signature: savedSignature, visibleRect: PieceBackLayout.visibleRect)
        // (100, 100)〜(300, 300) の線は、60〜340 を 1 辺 280 で出すと (40, 40)〜(240, 240)
        controller.layout(side: 280)
        #expect(abs(controller.canvasView.drawing.bounds.midX - 140) < 1)

        controller.layout(side: 560)
        #expect(abs(controller.canvasView.drawing.bounds.midX - 280) < 1)
        let saved = try PKDrawing(data: try #require(controller.signatureData()))
        #expect(abs(saved.bounds.midX - 200) < 1)
        #expect(abs(saved.bounds.midY - 200) < 1)
    }
}
