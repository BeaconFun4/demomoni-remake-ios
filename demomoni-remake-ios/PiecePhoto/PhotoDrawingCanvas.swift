//
//  PhotoDrawingCanvas.swift
//  demomoni-remake-ios
//

import PencilKit
import SwiftUI

/// 写真の上に手書きする `PKCanvasView`（`SignatureCanvasController` のもの）を置き、PencilKit のツールピッカーを出す。
/// ペンの種類・色・太さ・消しゴム・投げなわ・取り消しはツールピッカーで選ぶ
struct PhotoDrawingCanvas: UIViewRepresentable {
    let controller: SignatureCanvasController

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SignatureCanvasView {
        let canvasView = controller.canvasView
        let toolPicker = context.coordinator.toolPicker
        // アプリと同じライトの外観で、色を選んだとおりのインクにする（ダークの色に置き換えない）
        toolPicker.colorUserInterfaceStyle = .light
        toolPicker.overrideUserInterfaceStyle = .light
        toolPicker.addObserver(canvasView)
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        // ツールピッカーはキャンバスが first responder の間だけ出る。画面に置かれてから first responder にする
        Task { @MainActor in
            canvasView.becomeFirstResponder()
        }
        return canvasView
    }

    func updateUIView(_ canvasView: SignatureCanvasView, context: Context) {}

    static func dismantleUIView(_ canvasView: SignatureCanvasView, coordinator: Coordinator) {
        coordinator.toolPicker.setVisible(false, forFirstResponder: canvasView)
        coordinator.toolPicker.removeObserver(canvasView)
        canvasView.resignFirstResponder()
    }

    /// ツールピッカーを画面を出している間だけ持つ（持たないとすぐに消える）
    final class Coordinator {
        let toolPicker = PKToolPicker()
    }
}
