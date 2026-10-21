//
//  DemomoniApp.swift
//  demomoni-remake-ios
//
//  Created by 村石 拓海 on 2024/05/02.
//

import SwiftData
import SwiftUI

@main
struct DemomoniApp: App {
    /// ピースの獲得状態とサインを保存するストア
    let modelContainer: ModelContainer
    /// 近くの iBeacon の検知。さがすタブを表示している間だけ探す（起動引数 `-fakeBeaconID` で擬似検知）
    @State private var beaconDetector = BeaconDetector.live(options: .current, catalog: .bundled)

    init() {
        // 画面の文言に使うニコモジ+ を、最初の画面を描く前に登録する
        DemomoniFont.register()

        let options = LaunchOptions.current
        do {
            modelContainer = try .demomoni(inMemory: options.usesInMemoryStore)
            // UI テスト・PR の撮影のために、メモリ上のストアでだけ獲得済みのピースを用意する
            if options.usesInMemoryStore {
                let collection = PieceCollection(context: modelContainer.mainContext)
                for pieceID in options.collectedPieceIDs {
                    try collection.collect(pieceID: pieceID, at: .now)
                }
            }
        } catch {
            fatalError("獲得状態のストアを開けない: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // 元アプリの色と画像は白地の前提（Color Set もライト・ダークで同じ値）なので、ライトに固定する
                .preferredColorScheme(.light)
                .environment(beaconDetector)
        }
        .modelContainer(modelContainer)
    }
}
