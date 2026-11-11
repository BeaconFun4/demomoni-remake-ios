//
//  PieceDetailView.swift
//  demomoni-remake-ios
//

import SwiftData
import SwiftUI

/// ピース詳細。ピースの画像（サインがあれば重ねる）と、獲得した日時・エリア・場所を出す
struct PieceDetailView: View {
    let piece: Piece

    /// このピースの獲得の記録
    @Query private var records: [CollectedPiece]

    init(piece: Piece) {
        self.piece = piece
        let pieceID = piece.id
        _records = Query(filter: #Predicate<CollectedPiece> { $0.pieceID == pieceID })
    }

    @State private var showsSignature = false
    #if DEBUG
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    /// 「日時を変える」のシートを出しているか
    @State private var editsCollectedAt = false
    /// 編集を保存できなかったときに出す文言
    @State private var errorMessage: String?
    #endif

    private var record: CollectedPiece? {
        records.first
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text(PieceDetailText.title(for: piece))
                    .font(.demomoni(size: 40, relativeTo: .largeTitle))
                    .accessibilityAddTraits(.isHeader)

                PieceWithSignature(piece: piece, signature: record?.signature)
                    .containerRelativeFrame(.horizontal) { width, _ in
                        min(width * 0.8, 400)
                    }

                Button("サインをかく！") {
                    showsSignature = true
                }
                .font(.demomoni(size: 26, relativeTo: .title2))
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .tint(.themeColorPink)
                .foregroundStyle(Color.themeColorGray)
                // 獲得していないピースにはサインを保存できない
                .disabled(record == nil)

                VStack(alignment: .leading, spacing: 12) {
                    Text(PieceDetailText.date(record?.collectedAt))
                    Text(PieceDetailText.area(for: piece))
                    Text(PieceDetailText.place(for: piece))
                }
                .font(.demomoni(size: 24, relativeTo: .title3))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
                .glassEffect(.regular, in: .rect(cornerRadius: 24))
                .frame(maxWidth: 600)
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .background(Color.themeColorBlue)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showsSignature) {
            SignatureView(piece: piece, signature: record?.signature)
        }
        #if DEBUG
        .toolbar {
            // 獲得済みのときだけ編集できる
            if let record {
                ToolbarItem(placement: .primaryAction) {
                    editMenu(record: record)
                }
            }
        }
        .sheet(isPresented: $editsCollectedAt) {
            if let record {
                CollectedAtEditView(collectedAt: record.collectedAt) { date in
                    try PieceCollection(context: modelContext).updateCollectedAt(date, pieceID: piece.id)
                }
            }
        }
        .alert("保存できませんでした", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        #endif
    }

    #if DEBUG
    /// Debug 版だけの編集の操作（日時を変える・サインを消す・外す）
    private func editMenu(record: CollectedPiece) -> some View {
        Menu {
            Button("日時を変える", systemImage: "calendar") {
                editsCollectedAt = true
            }
            Button("サインを消す", systemImage: "signature") {
                write { try $0.saveSignature(nil, pieceID: piece.id) }
            }
            .disabled(record.signature == nil)
            Button("外す", systemImage: "trash", role: .destructive) {
                // 外したら盤へ戻る（盤には `@Query` で空きマスとして出る）
                if write({ try $0.remove(pieceID: piece.id) }) {
                    dismiss()
                }
            }
        } label: {
            Label("編集", systemImage: "pencil")
        }
        .accessibilityLabel("編集")
    }

    /// 獲得の記録を書き換える。保存できなければ「保存できませんでした」を出す
    /// - Returns: 書き換えられたか
    @discardableResult
    private func write(_ change: (PieceCollection) throws -> Bool) -> Bool {
        do {
            if try change(PieceCollection(context: modelContext)) {
                return true
            }
            errorMessage = "このピースはまだゲットしていません"
        } catch {
            errorMessage = error.localizedDescription
        }
        return false
    }
    #endif
}

/// ピースの画像に、保存したサインを重ねたもの
struct PieceWithSignature: View {
    let piece: Piece
    /// サインの `PKDrawing` のデータ。無ければピースの画像だけ
    let signature: Data?

    /// サインの画像。描き直すたびにデコードしないよう、サインのデータが変わったときだけ作る
    @State private var signatureImage: UIImage?

    var body: some View {
        Image(piece.image)
            .resizable()
            .scaledToFit()
            .overlay {
                if let signatureImage {
                    Image(uiImage: signatureImage)
                        .resizable()
                        .scaledToFit()
                }
            }
            .task(id: signature) {
                signatureImage = signature.flatMap { SignatureDrawing.image(from: $0) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(signatureImage == nil ? "ピースの画像" : "サインをかいたピースの画像")
    }
}

#Preview {
    NavigationStack {
        PieceDetailView(piece: Catalog.bundled.pieces[0])
    }
    // swiftlint:disable:next force_try
    .modelContainer(try! .demomoni(inMemory: true))
}
