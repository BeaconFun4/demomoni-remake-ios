//
//  SettingsView.swift
//  demomoni-remake-ios
//

import SwiftUI

/// せっていタブ。アプリのバージョンと、同梱しているフォントのライセンスを出す
struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("このアプリについて") {
                    LabeledContent("バージョン", value: SettingsInfo.versionText(infoDictionary: Bundle.main.infoDictionary))
                }
                Section("ライセンス") {
                    NavigationLink("ニコモジ+（SIL OFL 1.1）") {
                        FontLicenseView()
                    }
                }
            }
            .font(.demomoni(size: 18, relativeTo: .body))
            .scrollContentBackground(.hidden)
            .background(Color.themeColorBlue)
            .navigationTitle("せってい")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tabItem {
            Image(systemName: "gearshape.fill")
            Text("せってい")
        }
    }
}

/// ニコモジ+ のライセンスの本文（英語の原文のまま出す）。
/// 英語の長い文なので、ニコモジ+ ではなく等幅の小さい文字にし、読みやすいよう背景を白にする
private struct FontLicenseView: View {
    /// 本文。`NavigationLink` が行を描くたびにこの View を作るので、ファイルは画面を開いたときに読む
    @State private var text = ""

    var body: some View {
        ScrollView {
            Text(text)
                .font(.footnote.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .background(Color.white)
        .navigationTitle("ニコモジ+")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            text = SettingsInfo.fontLicenseText() ?? "ライセンスの本文を読み込めませんでした"
        }
    }
}

#Preview {
    TabView {
        SettingsView()
    }
}
