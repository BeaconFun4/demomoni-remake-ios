//
//  ContentView.swift
//  demomoni-remake-ios
//
//  Created by 村石 拓海 on 2024/05/02.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    /// 表示しているタブ。通知を開いたとき・デバッグモードの擬似検知で外から切り替える
    @Environment(TabSelection.self) private var tabSelection

    var body: some View {
        @Bindable var tabSelection = tabSelection
        TabView(selection: $tabSelection.selected) {
            RiddleView()
                .tag(AppTab.riddle)

            SearchView()
                .tag(AppTab.search)

            PieceListView()
                .tag(AppTab.pieceList)

            SettingsView()
                .tag(AppTab.settings)
        }
        // タブの選択色は元アプリのピンク
        .tint(.themeColorPink)
        #if DEBUG
        // デバッグモードの擬似検知で、さがすタブに切り替える
        .environment(\.showSearchTab, ShowSearchTabAction { tabSelection.selected = .search })
        #endif
    }
}

#if DEBUG
/// さがすタブに切り替える（Debug 構成だけ。デバッグモードの擬似検知で使う）
struct ShowSearchTabAction {
    let action: () -> Void

    func callAsFunction() {
        action()
    }
}

extension EnvironmentValues {
    /// さがすタブに切り替える。`ContentView` の外（プレビューなど）では何もしない
    @Entry var showSearchTab = ShowSearchTabAction {}
}
#endif

#Preview {
    let options = LaunchOptions(usesLocationServices: false)
    // swiftlint:disable:next force_try
    let container = try! ModelContainer.demomoni(inMemory: true)
    ContentView()
        .environment(TabSelection())
        .environment(BeaconDetector.live(options: options, catalog: .bundled))
        .environment(NearbyPieceAlerts.live(options: options, catalog: .bundled, container: container))
        .modelContainer(container)
}
