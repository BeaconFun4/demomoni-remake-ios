//
//  DemomoniApp.swift
//  demomoni-remake-ios
//
//  Created by 村石 拓海 on 2024/05/02.
//

import SwiftData
import SwiftUI
import UserNotifications

@main
struct DemomoniApp: App {
    /// ピースの獲得状態とサインを保存するストア
    let modelContainer: ModelContainer
    /// 近くの iBeacon の検知。さがすタブを表示している間だけ探す（起動引数 `-fakeBeaconID` で擬似検知）
    @State private var beaconDetector = BeaconDetector.live(options: .current, catalog: .bundled)
    /// オンにした人だけ、アプリを閉じていても近くのピースを通知で知らせる
    @State private var nearbyPieceAlerts: NearbyPieceAlerts
    /// 表示しているタブ。通知を開いたときに外から切り替える
    @State private var tabSelection: TabSelection
    /// 近くのピースの通知を開いたときに、さがすタブに切り替える（`UNUserNotificationCenter` の delegate は弱い参照なので、ここで持つ）
    private let notificationResponder: PieceNotificationResponder
    @Environment(\.scenePhase) private var scenePhase

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

        // 通知から起動したときも開いたことを受け取れるよう、起動を終える前に delegate にする
        let tabSelection = TabSelection()
        _tabSelection = State(initialValue: tabSelection)
        notificationResponder = PieceNotificationResponder(tabSelection: tabSelection)
        UNUserNotificationCenter.current().delegate = notificationResponder

        // CLMonitor の出来事でバックグラウンドに起こされたときは画面が作られないこともあるので、ここで見張りを再開する
        let alerts = NearbyPieceAlerts.live(options: options, catalog: .bundled, container: modelContainer)
        _nearbyPieceAlerts = State(initialValue: alerts)
        Task {
            await alerts.refresh()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // 元アプリの色と画像は白地の前提（Color Set もライト・ダークで同じ値）なので、ライトに固定する
                .preferredColorScheme(.light)
                .environment(beaconDetector)
                .environment(nearbyPieceAlerts)
                .environment(tabSelection)
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, phase in
            // 設定アプリで許可を変えて戻ったとき・獲得してから閉じたときに、見張る条件を決め直す
            guard phase != .inactive else {
                return
            }
            Task {
                await nearbyPieceAlerts.refresh()
            }
        }
    }
}
