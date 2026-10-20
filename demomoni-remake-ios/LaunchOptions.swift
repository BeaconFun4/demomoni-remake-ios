//
//  LaunchOptions.swift
//  demomoni-remake-ios
//

import Foundation

/// 起動引数で切り替える動作。UI テスト・PR のスクリーンショットの撮影で使う
nonisolated struct LaunchOptions: Equatable, Sendable {
    /// `-uiTesting`: 獲得状態を端末に保存せず、メモリ上の空のストアで起動する
    var usesInMemoryStore = false
    /// `-fakeBeaconID <id>`: CoreLocation の代わりに、その beaconId のビーコンを数秒後に見つけたことにする（擬似検知）
    var fakeBeaconID: Int?

    init(usesInMemoryStore: Bool = false, fakeBeaconID: Int? = nil) {
        self.usesInMemoryStore = usesInMemoryStore
        self.fakeBeaconID = fakeBeaconID
    }

    /// 起動引数（`ProcessInfo.processInfo.arguments`）から読む
    init(arguments: [String]) {
        usesInMemoryStore = arguments.contains("-uiTesting")
        if let index = arguments.firstIndex(of: "-fakeBeaconID"), arguments.indices.contains(index + 1) {
            fakeBeaconID = Int(arguments[index + 1])
        }
    }

    /// このプロセスの起動引数
    static let current = Self(arguments: ProcessInfo.processInfo.arguments)
}
