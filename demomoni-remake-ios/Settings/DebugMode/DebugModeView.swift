//
//  DebugModeView.swift
//  demomoni-remake-ios
//

#if DEBUG
import SwiftData
import SwiftUI

/// デバッグモード（Debug 構成だけ。App Store 版には入れない）。
/// ピースを 1 つずつ埋める・外す、全部埋める、全部リセットする。書き込みは `PieceCollection` だけで行う。
/// ピースを選んで擬似検知し、さがすタブの「ゲットした」画面まで通すこともできる
struct DebugModeView: View {
    @Environment(\.catalog) private var catalog
    @Environment(\.modelContext) private var modelContext
    @Query private var collected: [CollectedPiece]

    @State private var confirmsReset = false
    /// 保存に失敗したときに出す文言
    @State private var errorMessage: String?

    private var collection: PieceCollection {
        PieceCollection(context: modelContext)
    }

    private var rows: [DebugPieceList.Row] {
        DebugPieceList.rows(pieces: catalog.pieces, collectedPieceIDs: Set(collected.map(\.pieceID)))
    }

    var body: some View {
        List {
            Section {
                Button("全部埋める") {
                    perform { _ = try collection.collectAll(pieceIDs: catalog.pieces.map(\.id), at: .now) }
                }
                Button("全部リセット", role: .destructive) {
                    confirmsReset = true
                }
            } header: {
                Text("ぜんぶ（\(collected.count) / \(catalog.pieces.count) こ）")
            }

            Section {
                NavigationLink("ピースを選んで擬似検知する") {
                    DebugFakeDetectionView()
                }
            } header: {
                Text("ぎじけんち")
            } footer: {
                Text("選ぶとさがすタブに切り替わり、ビーコンを見つけたときと同じく「ピースをゲットしたよ！！」が出ます")
            }

            Section("ピース") {
                ForEach(rows) { row in
                    Toggle(row.title, isOn: Binding(
                        get: { row.isCollected },
                        set: { isOn in setCollected(isOn, pieceID: row.piece.id) }
                    ))
                }
            }
        }
        .font(.demomoni(size: 18, relativeTo: .body))
        .scrollContentBackground(.hidden)
        .background(Color.themeColorBlue)
        .navigationTitle("デバッグモード")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("ゲットしたピースを全部消しますか？", isPresented: $confirmsReset, titleVisibility: .visible) {
            Button("全部リセットする", role: .destructive) {
                perform { _ = try collection.removeAll() }
            }
        } message: {
            Text("獲得の日時とサインも消えます")
        }
        .alert("保存できませんでした", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func setCollected(_ isOn: Bool, pieceID: Int) {
        perform {
            if isOn {
                try collection.collect(pieceID: pieceID, at: .now)
            } else {
                try collection.remove(pieceID: pieceID)
            }
        }
    }

    /// 書き込む。失敗したら文言を出す（`PieceCollection` が保存前に戻している）
    private func perform(_ write: () throws -> Void) {
        do {
            try write()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        DebugModeView()
    }
    // swiftlint:disable:next force_try
    .modelContainer(try! .demomoni(inMemory: true))
}
#endif
