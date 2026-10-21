//
//  SettingsView.swift
//  demomoni-remake-ios
//

import SwiftData
import SwiftUI

/// せっていタブ。アプリを閉じていても近くのピースを知らせるスイッチ、アプリのバージョンと、同梱しているフォントのライセンスを出す。
/// Debug 構成だけ、デバッグモードへの入口を置く（App Store 版の Release 構成には入れない）
struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                NearbyPieceAlertSection()
                Section("このアプリについて") {
                    LabeledContent("バージョン", value: SettingsInfo.versionText(infoDictionary: Bundle.main.infoDictionary))
                }
                Section("ライセンス") {
                    NavigationLink("ニコモジ+（SIL OFL 1.1）") {
                        FontLicenseView()
                    }
                }
                #if DEBUG
                Section("デバッグ（Debug ビルドだけ）") {
                    NavigationLink("デバッグモード") {
                        DebugModeView()
                    }
                }
                #endif
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

/// 「アプリを閉じていても、近くのピースを知らせる」のスイッチ（既定はオフ）。
/// オンにしたときだけ通知と位置情報の「常に許可」を尋ね、足りない許可があればスイッチの下に案内を出す
private struct NearbyPieceAlertSection: View {
    @Environment(NearbyPieceAlerts.self) private var alerts

    var body: some View {
        Section {
            Toggle("アプリを閉じていても、近くのピースを知らせる", isOn: isEnabled)
        } header: {
            Text("おしらせ")
        } footer: {
            // 案内は行ではなく footer に置く（行にするとスイッチの行のカードが途中で切れて見える）
            VStack(spacing: 12) {
                if let message {
                    LocationPermissionNotice(message: message)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(Color.primary)
                }
                Text("まだゲットしていないピースの近くに来たら、通知でおしらせするよ")
                    .font(.demomoni(size: 14, relativeTo: .footnote))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// 足りない許可の案内。オフのとき・許可がそろっているときは `nil`
    private var message: String? {
        NearbyAlertPermissionStatus.message(isEnabled: alerts.preference.isEnabled, status: alerts.permissionStatus)
    }

    /// スイッチの値。切り替えたらすぐに保存し、許可を尋ねて見張るかを決め直す
    private var isEnabled: Binding<Bool> {
        Binding {
            alerts.preference.isEnabled
        } set: { newValue in
            alerts.preference.isEnabled = newValue
            Task {
                await alerts.preferenceDidChange()
            }
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
    // swiftlint:disable:next force_try
    let container = try! ModelContainer.demomoni(inMemory: true)
    TabView {
        SettingsView()
    }
    .environment(NearbyPieceAlerts.live(options: LaunchOptions(usesLocationServices: false), catalog: .bundled, container: container))
    .modelContainer(container)
}
