//
//  ContentView.swift
//  demomoni-remake-ios
//
//  Created by 村石 拓海 on 2024/05/02.
//

import SwiftUI

struct ContentView: View {
    /// さがすタブの tag
    static let searchTab = 2

    @State var selection = searchTab

    var body: some View {
        TabView(selection: $selection) {
            RiddleView()
                .tag(1)

            SearchView()
                .tag(Self.searchTab)

            PieceListView()
                .tag(3)

            SettingsView()
                .tag(4)
        }
        // タブの選択色は元アプリのピンク
        .tint(.themeColorPink)
        #if DEBUG
        // デバッグモードの擬似検知で、さがすタブに切り替える
        .environment(\.showSearchTab, ShowSearchTabAction { selection = Self.searchTab })
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
    ContentView()
}
