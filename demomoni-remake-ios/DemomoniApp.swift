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

    init() {
        // 画面の文言に使うニコモジ+ を、最初の画面を描く前に登録する
        DemomoniFont.register()

        do {
            modelContainer = try .demomoni(inMemory: LaunchOptions.current.usesInMemoryStore)
        } catch {
            fatalError("獲得状態のストアを開けない: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // 元アプリの色と画像は白地の前提（Color Set もライト・ダークで同じ値）なので、ライトに固定する
                .preferredColorScheme(.light)
        }
        .modelContainer(modelContainer)
    }
}
