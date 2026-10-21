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

/// ニコモジ+ のライセンスの本文（英語の原文のまま出す）
private struct FontLicenseView: View {
    private let text = SettingsInfo.fontLicenseText() ?? "ライセンスの本文を読み込めませんでした"

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
    }
}

#Preview {
    TabView {
        SettingsView()
    }
}
