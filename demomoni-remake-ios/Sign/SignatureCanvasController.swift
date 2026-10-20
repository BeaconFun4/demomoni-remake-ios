//
//  SignatureCanvasController.swift
//  demomoni-remake-ios
//

import Observation
import PencilKit

/// サインを描く `PKCanvasView` と、選んでいる道具。
/// 画面の大きさ（キャンバスの 1 辺）が決まってから、保存してあったサインをその大きさに直して置く
@Observable
final class SignatureCanvasController {
    /// 描く道具
    enum Tool: Equatable {
        case pen
        case eraser
    }

    /// 選んでいる道具
    private(set) var tool = Tool.pen

    /// 描くところ。`SignatureCanvas` がこの View を画面に置く
    @ObservationIgnored let canvasView = PKCanvasView()

    /// 今のキャンバスの 1 辺。まだ画面に出ていなければ `nil`
    @ObservationIgnored private var side: CGFloat?
    /// 最初に置く、保存してあったサイン（保存する座標のまま）
    @ObservationIgnored private var initialDrawing: PKDrawing?

    /// - Parameter signature: 保存してあったサインのデータ。描き足せるように最初に置く
    init(signature: Data?) {
        initialDrawing = signature.flatMap { try? PKDrawing(data: $0) }
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.accessibilityLabel = "サインをかくところ"
        canvasView.overrideUserInterfaceStyle = .light
        select(.pen)
    }

    /// キャンバスの 1 辺が決まった・変わった。サインをその大きさに合わせて描き直す
    func layout(side newSide: CGFloat) {
        guard newSide > 0, newSide != side else {
            return
        }
        if let side {
            // 回転などで大きさが変わったら、描いたものも同じ割合で拡大・縮小する
            canvasView.drawing = SignatureDrawing.denormalized(
                SignatureDrawing.normalized(canvasView.drawing, fromSide: side),
                toSide: newSide
            )
        } else if let initialDrawing {
            canvasView.drawing = SignatureDrawing.denormalized(initialDrawing, toSide: newSide)
        }
        side = newSide
    }

    /// 道具を選ぶ
    func select(_ newTool: Tool) {
        tool = newTool
        switch newTool {
        case .pen:
            canvasView.tool = PKInkingTool(.pen, color: .black, width: 6)
        case .eraser:
            canvasView.tool = PKEraserTool(.vector)
        }
    }

    /// 描いたものをぜんぶ消す（「もどる！」で取り消せる）
    func clear() {
        let previous = canvasView.drawing
        canvasView.drawing = PKDrawing()
        canvasView.undoManager?.registerUndo(withTarget: canvasView) { canvas in
            canvas.drawing = previous
        }
    }

    /// ひとつ前に戻す
    func undo() {
        canvasView.undoManager?.undo()
    }

    /// 保存するサインのデータ（保存する座標に直したもの）
    func signatureData() -> Data {
        let drawing = side.map { SignatureDrawing.normalized(canvasView.drawing, fromSide: $0) } ?? canvasView.drawing
        return drawing.dataRepresentation()
    }
}
