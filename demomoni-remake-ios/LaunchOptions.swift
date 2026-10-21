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
    /// 実際の位置情報（CoreLocation）で探すか。`-uiTesting` と Unit テストのホストでは使わない
    /// （位置情報の許可のダイアログがテストの画面を塞がないようにする）
    var usesLocationServices = true
    /// `-collectedPieceIDs <id>,<id>`: メモリ上のストアで、そのピースを獲得済みにして起動する（`-uiTesting` と一緒に使う）
    var collectedPieceIDs: [Int] = []

    init(
        usesInMemoryStore: Bool = false,
        fakeBeaconID: Int? = nil,
        usesLocationServices: Bool = true,
        collectedPieceIDs: [Int] = []
    ) {
        self.usesInMemoryStore = usesInMemoryStore
        self.fakeBeaconID = fakeBeaconID
        self.usesLocationServices = usesLocationServices
        self.collectedPieceIDs = collectedPieceIDs
    }

    /// 起動引数（`ProcessInfo.processInfo.arguments`）と環境変数から読む
    init(arguments: [String], environment: [String: String] = [:]) {
        let isUITesting = arguments.contains("-uiTesting")
        usesInMemoryStore = isUITesting
        // Unit テストはアプリをホストにして動くので、XCTest が渡す環境変数で見分ける
        usesLocationServices = !isUITesting && environment["XCTestConfigurationFilePath"] == nil
        if let index = arguments.firstIndex(of: "-fakeBeaconID"), arguments.indices.contains(index + 1) {
            fakeBeaconID = Int(arguments[index + 1])
        }
        if let index = arguments.firstIndex(of: "-collectedPieceIDs"), arguments.indices.contains(index + 1) {
            collectedPieceIDs = arguments[index + 1].split(separator: ",").compactMap { Int($0) }
        }
    }

    /// このプロセスの起動引数
    static let current = Self(arguments: ProcessInfo.processInfo.arguments, environment: ProcessInfo.processInfo.environment)
}
