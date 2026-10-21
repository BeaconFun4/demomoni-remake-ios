//
//  DebugFakeDetectionView.swift
//  demomoni-remake-ios
//

#if DEBUG
import SwiftData
import SwiftUI

/// デバッグモードの擬似検知（Debug 構成だけ）。まだ獲得していないピースを選ぶと、
/// そのピースのビーコンを見つけたことにして、さがすタブに切り替える。
/// さがすタブは表示している間だけ探すので、検知は `BeaconDetector` が持っておき、さがすタブが探し始めたときに届く
struct DebugFakeDetectionView: View {
    @Environment(\.catalog) private var catalog
    @Environment(BeaconDetector.self) private var detector
    @Environment(\.showSearchTab) private var showSearchTab
    @Query private var collected: [CollectedPiece]

    private var rows: [DebugPieceList.Row] {
        DebugPieceList.detectableRows(pieces: catalog.pieces, collectedPieceIDs: Set(collected.map(\.pieceID)))
    }

    var body: some View {
        List {
            Section {
                ForEach(rows) { row in
                    Button(row.title) {
                        detect(pieceID: row.piece.id)
                    }
                }
            } footer: {
                Text(rows.isEmpty
                    ? "全部ゲットしています。デバッグモードでピースを外すと選べます"
                    : "ゲットしたピースは出していません（デバッグモードで外すと選べます）")
            }
        }
        .font(.demomoni(size: 18, relativeTo: .body))
        .scrollContentBackground(.hidden)
        .background(Color.themeColorBlue)
        .navigationTitle("擬似検知")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detect(pieceID: Int) {
        guard detector.injectDetection(pieceID: pieceID) else {
            return
        }
        showSearchTab()
    }
}

#Preview {
    NavigationStack {
        DebugFakeDetectionView()
    }
    .environment(BeaconDetector.live(options: LaunchOptions(usesLocationServices: false), catalog: .bundled))
    // swiftlint:disable:next force_try
    .modelContainer(try! .demomoni(inMemory: true))
}
#endif
