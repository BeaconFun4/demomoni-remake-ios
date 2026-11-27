//
//  PhotoDrawingView.swift
//  demomoni-remake-ios
//

import SwiftData
import SwiftUI

/// ピースの裏側の写真の上に手書きする画面（サイン・落書き・飾り）。
/// ピース詳細の裏側と同じく、ピースを裏から見た形の中の写真に、画面の幅いっぱいの大きさで描く。描いたものも形の外には出さない。
/// ペンの種類・色・消しゴムは PencilKit のツールピッカーで選ぶ。
/// 「これでかんせい！」で保存して閉じ、「ピースがめんにもどる」で保存せずに閉じる
struct PhotoDrawingView: View {
    let piece: Piece
    /// 下に敷く写真の JPEG
    let photo: Data

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var controller: SignatureCanvasController
    /// 保存に失敗したことを知らせるか
    @State private var showsSaveError = false

    /// - Parameter drawing: 保存してあった手書き。描き足せるように最初に置く
    init(piece: Piece, photo: Data, drawing: Data?) {
        self.piece = piece
        self.photo = photo
        // キャンバスには、400 × 400 の座標のうちピースが入るまんなかだけを出す（ピース詳細の裏側と同じ範囲）
        _controller = State(initialValue: SignatureCanvasController(
            signature: drawing,
            accessibilityLabel: "しゃしんにかきこむところ",
            visibleRect: PieceBackLayout.visibleRect
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                canvas
                Button("ぜんぶけす！", systemImage: "trash") {
                    controller.clear()
                }
                .font(.demomoni(size: 18, relativeTo: .body))
                .buttonStyle(.glass)
                .foregroundStyle(Color.themeColorGray)
                // 画面の下にはツールピッカーが出るので、写真は上に寄せる
                Spacer(minLength: 0)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.themeColorBlue)
            .navigationTitle("しゃしんにかきこむ")
            .navigationBarTitleDisplayMode(.inline)
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
            .alert("かきこみをほぞんできませんでした", isPresented: $showsSaveError) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    /// 写真の上に描くところ。ピース詳細の裏側と同じ形・同じ範囲で、画面の幅いっぱいに出す。
    /// 描いた線もピースを裏から見た形で切り抜き、形の外には出さない
    private var canvas: some View {
        ZStack {
            PieceBackSurface(piece: piece, photo: photo, drawing: nil)
                .accessibilityHidden(true)
            PhotoDrawingCanvas(controller: controller)
                .mask {
                    PieceBackSilhouette(piece: piece)
                }
        }
        .aspectRatio(1, contentMode: .fit)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { side in
            controller.layout(side: side)
        }
        .frame(maxWidth: PieceBackLayout.maximumBackSide)
    }

    /// 手書きを保存して閉じる。保存できなければ知らせて、描いたものは残す
    private func save() {
        do {
            let saved = try PieceCollection(context: modelContext)
                .savePhotoDrawing(controller.signatureData(), pieceID: piece.id)
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
