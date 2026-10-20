//
//  SignatureCanvas.swift
//  demomoni-remake-ios
//

import PencilKit
import SwiftUI

/// `SignatureCanvasController` の `PKCanvasView` を SwiftUI に置く
struct SignatureCanvas: UIViewRepresentable {
    let controller: SignatureCanvasController

    func makeUIView(context: Context) -> PKCanvasView {
        controller.canvasView
    }

    func updateUIView(_ canvasView: PKCanvasView, context: Context) {}
}
