//
//  PhotoDrawingView.swift
//  demomoni-remake-ios
//

import SwiftData
import SwiftUI

/// ピースの裏側の写真の上に手書きする画面（サイン・落書き・飾り）。
/// 写真を正方形に切り抜いた枠の上に描き、ペンの種類・色・消しゴムは PencilKit のツールピッカーで選ぶ。
/// 「これでかんせい！」で保存して閉じ、「ピースがめんにもどる」で保存せずに閉じる
struct PhotoDrawingView: View {
    let pieceID: Int
    /// 下に敷く写真の JPEG
    let photo: Data

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var controller: SignatureCanvasController
    /// 保存に失敗したことを知らせるか
    @State private var showsSaveError = false

    /// - Parameter drawing: 保存してあった手書き。描き足せるように最初に置く
    init(pieceID: Int, photo: Data, drawing: Data?) {
        self.pieceID = pieceID
        self.photo = photo
        _controller = State(initialValue: SignatureCanvasController(signature: drawing, accessibilityLabel: "しゃしんにかきこむところ"))
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

    /// 写真の上に描くところ。写真を正方形に切り抜いた枠と同じ大きさ
    private var canvas: some View {
        ZStack {
            PiecePhotoSquare(photo: photo, drawing: nil)
                .accessibilityHidden(true)
            PhotoDrawingCanvas(controller: controller)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 16))
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { side in
            controller.layout(side: side)
        }
        .frame(maxWidth: 600)
    }

    /// 手書きを保存して閉じる。保存できなければ知らせて、描いたものは残す
    private func save() {
        do {
            let saved = try PieceCollection(context: modelContext)
                .savePhotoDrawing(controller.signatureData(), pieceID: pieceID)
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
