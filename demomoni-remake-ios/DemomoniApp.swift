//
//  DemomoniApp.swift
//  demomoni-remake-ios
//
//  Created by 村石 拓海 on 2024/05/02.
//

import SwiftUI

@main
struct DemomoniApp: App {
    init() {
        // 画面の文言に使うニコモジ+ を、最初の画面を描く前に登録する
        DemomoniFont.register()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
