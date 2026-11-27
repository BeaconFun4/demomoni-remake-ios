//
//  PieceDetailView.swift
//  demomoni-remake-ios
//

import SwiftData
import SwiftUI

/// ピース詳細。ピースの画像（サインがあれば重ねる）と、獲得した日時・エリア・場所を出す。
/// ピースを「うらがえす」と裏側が出て、その場所で撮った写真を入れ、写真の上に手書きできる
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
    /// 裏側（写真）を出しているか
    @State private var showsBack = false
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

                // 置き場所は裏の大きさ（画面の幅いっぱい）。表は今までの大きさ（画面の幅の 8 割・400 まで）に縮めて出す
                PieceFlipCard(showsBack: showsBack) {
                    PieceWithSignature(piece: piece, signature: record?.signature)
                } back: {
                    PieceBackSide(piece: piece, photo: record?.photo, drawing: record?.photoDrawing)
                }
                .containerRelativeFrame(.horizontal) { width, _ in
                    PieceBackLayout.backSide(containerWidth: width)
                }
                .contentShape(.rect)
                // ピースを押してもうらがえせる（読み上げでは下の「うらがえす」を使う）
                .onTapGesture {
                    flip()
                }

                if showsBack, let record {
                    PiecePhotoActions(piece: piece, photo: record.photo, drawing: record.photoDrawing)
                } else {
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
                }

                Button("うらがえす", systemImage: "arrow.trianglehead.2.clockwise.rotate.90") {
                    flip()
                }
                .font(.demomoni(size: 18, relativeTo: .body))
                .buttonStyle(.glass)
                .foregroundStyle(Color.themeColorGray)
                .accessibilityValue(showsBack ? "うら" : "おもて")
                // 獲得していないピースの裏には写真を保存できない
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

                // 場所の地図。押すと大きな地図を開く
                PieceLocationMap(piece: piece)
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

    /// 表と裏を入れ替える。獲得していないピースはうらがえさない（裏に写真を保存できない）
    private func flip() {
        guard record != nil else {
            return
        }
        showsBack.toggle()
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
