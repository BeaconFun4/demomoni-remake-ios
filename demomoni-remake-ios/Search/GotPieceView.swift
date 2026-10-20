//
//  GotPieceView.swift
//  demomoni-remake-ios
//

import SwiftUI

/// 「ピースをゲットしたよ！！」画面。獲得したピースの画像と、名前・日付・検知場所（エリア）を出す
struct GotPieceView: View {
    let gotPiece: GotPiece

    @Environment(\.dismiss) private var dismiss

    private var piece: Piece {
        gotPiece.piece
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("ピースをゲットしたよ！！")
                        .font(.demomoni(size: 30, relativeTo: .largeTitle))
                        .multilineTextAlignment(.center)

                    Image(piece.image)
                        .resizable()
                        .scaledToFit()
                        .containerRelativeFrame(.horizontal) { width, _ in
                            min(width * 0.8, 400)
                        }
                        .accessibilityLabel("ピースの画像")

                    VStack(spacing: 12) {
                        Text(piece.name)
                            .font(.demomoni(size: 26, relativeTo: .title2))
                        Text(PieceDateFormat.gotDate(gotPiece.collectedAt))
                            .font(.demomoni(size: 20, relativeTo: .body))
                        Text(piece.area)
                            .font(.demomoni(size: 20, relativeTo: .body))
                            .accessibilityLabel("検知場所、\(piece.area)")
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .glassEffect(.regular, in: .rect(cornerRadius: 24))
                }
                .padding()
            }
            .background(Color.themeColorBlue)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("とじる", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    GotPieceView(gotPiece: GotPiece(piece: Catalog.bundled.pieces[0], collectedAt: .now))
}
