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

                // サインを描く画面は次のタスクで作り、ここから開く
                Button("サインをかく！") {}
                    .font(.demomoni(size: 26, relativeTo: .title2))
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .tint(.themeColorPink)
                    .foregroundStyle(Color.themeColorGray)
                    .disabled(true)

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
    }
}

/// ピースの画像に、保存したサインを重ねたもの
struct PieceWithSignature: View {
    let piece: Piece
    /// サインの `PKDrawing` のデータ。無ければピースの画像だけ
    let signature: Data?

    var body: some View {
        Image(piece.image)
            .resizable()
            .scaledToFit()
            .overlay {
                if let signature, let image = SignatureDrawing.image(from: signature) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(signature == nil ? "ピースの画像" : "サインをかいたピースの画像")
    }
}

#Preview {
    NavigationStack {
        PieceDetailView(piece: Catalog.bundled.pieces[0])
    }
    // swiftlint:disable:next force_try
    .modelContainer(try! .demomoni(inMemory: true))
}
