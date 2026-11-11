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
    #if DEBUG
    @Environment(\.modelContext) private var modelContext
    /// 空きマスを埋められなかったときに出す文言
    @State private var errorMessage: String?
    #endif

    /// 獲得したピース（同梱データの順）
    private var collectedPieces: [Piece] {
        let ids = Set(collected.map(\.pieceID))
        return catalog.pieces.filter { ids.contains($0.id) }
    }

    #if DEBUG
    /// 獲得していないピース（同梱データの順）
    private var uncollectedPieces: [Piece] {
        let ids = Set(collected.map(\.pieceID))
        return catalog.pieces.filter { !ids.contains($0.id) }
    }
    #endif

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
                #if DEBUG
                PieceBoard(
                    pieces: collectedPieces,
                    signatures: signatures,
                    emptyPieces: uncollectedPieces,
                    fill: fill
                )
                #else
                PieceBoard(pieces: collectedPieces, signatures: signatures)
                #endif
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.themeColorBlue)
            .navigationTitle("いちらん")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Piece.self) { piece in
                PieceDetailView(piece: piece)
            }
            #if DEBUG
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
        .tabItem {
            Image(systemName: "puzzlepiece.extension")
            Text("いちらん")
        }
    }

    #if DEBUG
    /// 空きマスのピースを、確かめずにすぐ獲得済みにする（日時は押した時刻）。盤には `@Query` で出る
    private func fill(_ piece: Piece) {
        do {
            try PieceCollection(context: modelContext).collect(pieceID: piece.id, at: .now)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    #endif
}

#Preview {
    TabView {
        PieceListView()
    }
    // swiftlint:disable:next force_try
    .modelContainer(try! .demomoni(inMemory: true))
}
