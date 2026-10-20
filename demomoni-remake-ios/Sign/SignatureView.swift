//
//  SignatureView.swift
//  demomoni-remake-ios
//

import SwiftData
import SwiftUI

/// ピースにサインを描く画面。背景はそのピースの画像。
/// 「これでかんせい！」で保存して閉じ、「ピースがめんにもどる」で保存せずに閉じる
struct SignatureView: View {
    let piece: Piece

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var controller: SignatureCanvasController
    /// 保存に失敗したことを知らせるか
    @State private var showsSaveError = false

    /// - Parameter signature: 保存してあったサイン。描き足せるように最初に置く
    init(piece: Piece, signature: Data?) {
        self.piece = piece
        _controller = State(initialValue: SignatureCanvasController(signature: signature))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                canvas
                tools
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.themeColorBlue)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ピースがめんにもどる") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("これでかんせい！") {
                        save()
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.themeColorPink)
                    .foregroundStyle(Color.themeColorGray)
                }
            }
            .alert("サインをほぞんできませんでした", isPresented: $showsSaveError) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    /// ピースの画像の上に描くところ。ピースの画像と同じ正方形
    private var canvas: some View {
        ZStack {
            Color.themeColorWhite
            Image(piece.image)
                .resizable()
                .scaledToFit()
                .accessibilityHidden(true)
            SignatureCanvas(controller: controller)
        }
        .aspectRatio(1, contentMode: .fit)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { side in
            controller.layout(side: side)
        }
        .frame(maxWidth: 600, maxHeight: .infinity)
    }

    /// 「ぺん」「けしごむ」「ぜんぶけす！」「もどる！」
    private var tools: some View {
        GlassEffectContainer {
            HStack(spacing: 12) {
                toolButton("ぺん", image: .pen, isSelected: controller.tool == .pen) {
                    controller.select(.pen)
                }
                toolButton("けしごむ", image: .eraser, isSelected: controller.tool == .eraser) {
                    controller.select(.eraser)
                }
                toolButton("ぜんぶけす！", image: .clear, isSelected: false) {
                    controller.clear()
                }
                toolButton("もどる！", image: .undo, isSelected: false) {
                    controller.undo()
                }
            }
        }
        .font(.demomoni(size: 16, relativeTo: .callout))
    }

    /// 道具のボタン。選んでいる道具はピンクのガラスにする
    @ViewBuilder
    private func toolButton(
        _ title: LocalizedStringKey,
        image: ImageResource,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let button = Button(action: action) {
            VStack(spacing: 4) {
                Image(image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        if isSelected {
            button
                .buttonStyle(.glassProminent)
                .tint(.themeColorPink)
                .foregroundStyle(Color.themeColorGray)
        } else {
            button
                .buttonStyle(.glass)
                .foregroundStyle(Color.themeColorGray)
        }
    }

    /// サインを保存して閉じる。保存できなければ知らせて、描いたものは残す
    private func save() {
        do {
            let saved = try PieceCollection(context: modelContext)
                .saveSignature(controller.signatureData(), pieceID: piece.id)
            if saved {
                dismiss()
            } else {
                showsSaveError = true
            }
        } catch {
            showsSaveError = true
        }
    }
}
