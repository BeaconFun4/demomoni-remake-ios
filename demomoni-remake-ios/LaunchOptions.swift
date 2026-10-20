//
//  LaunchOptions.swift
//  demomoni-remake-ios
//

import Foundation

/// 起動引数で切り替える動作。UI テスト・PR のスクリーンショットの撮影で使う
nonisolated struct LaunchOptions: Equatable, Sendable {
    /// `-uiTesting`: 獲得状態を端末に保存せず、メモリ上の空のストアで起動する
    var usesInMemoryStore = false

    init(usesInMemoryStore: Bool = false) {
        self.usesInMemoryStore = usesInMemoryStore
    }

    /// 起動引数（`ProcessInfo.processInfo.arguments`）から読む
    init(arguments: [String]) {
        usesInMemoryStore = arguments.contains("-uiTesting")
    }

    /// このプロセスの起動引数
    static let current = Self(arguments: ProcessInfo.processInfo.arguments)
}
