//
//  PieceListView.swift
//  demomoni-remake-ios
//
//  Created by 村石 拓海 on 2024/05/02.
//

import SwiftData
import SwiftUI

/// いちらんタブ。獲得したピースを五稜郭の盤に並べ、押すとピース詳細を開く
struct PieceListView: View {
    @Environment(\.catalog) private var catalog
    @Query private var collected: [CollectedPiece]

    /// 獲得したピース（同梱データの順）
    private var collectedPieces: [Piece] {
        let ids = Set(collected.map(\.pieceID))
        return catalog.pieces.filter { ids.contains($0.id) }
    }

    /// 獲得したピースのサイン
    private var signatures: [Int: Data] {
        Dictionary(uniqueKeysWithValues: collected.compactMap { record in
            record.signature.map { (record.pieceID, $0) }
        })
    }

    /// 盤の上に出す数（ゲットした数 / 同梱の全部の数）
    private var pieceCount: PieceCount {
        PieceCount(pieces: catalog.pieces, collectedPieceIDs: collected.map(\.pieceID))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text(pieceCount.text)
                    .font(.demomoni(size: 26, relativeTo: .title2))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .accessibilityLabel(pieceCount.accessibilityLabel)
                PieceBoard(pieces: collectedPieces, signatures: signatures)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.themeColorBlue)
            .navigationTitle("いちらん")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Piece.self) { piece in
                PieceDetailView(piece: piece)
            }
        }
        .tabItem {
            Image(systemName: "puzzlepiece.extension")
            Text("いちらん")
        }
    }
}

#Preview {
    TabView {
        PieceListView()
    }
    // swiftlint:disable:next force_try
    .modelContainer(try! .demomoni(inMemory: true))
}
