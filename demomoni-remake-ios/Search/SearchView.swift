//
//  SearchView.swift
//  demomoni-remake-ios
//
//  Created by 村石 拓海 on 2024/05/02.
//

import SwiftUI

/// さがすタブ。表示している間だけ近くの iBeacon を探す。
/// 歩くうさぎと道を出し、`genbausa` のボタンでチュートリアルを開く
struct SearchView: View {
    @Environment(BeaconDetector.self) private var detector
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsTutorial = false
    /// さがすタブが画面に出ているか。`TabView` はほかのタブにいる間も View を残すので、自分で持つ
    @State private var isVisible = false

    /// 今、探すべきか
    private var shouldScan: Bool {
        Self.shouldScan(isVisible: isVisible, scenePhase: scenePhase)
    }

    /// さがすタブが画面に出ていて、アプリがバックグラウンドでないときだけ探す
    nonisolated static func shouldScan(isVisible: Bool, scenePhase: ScenePhase) -> Bool {
        isVisible && scenePhase != .background
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("まちをあるいてみよう！！")
                    .font(.demomoni(size: 26, relativeTo: .title))
                    .multilineTextAlignment(.center)

                if let message = LocationPermissionNotice.message(for: detector.permission) {
                    LocationPermissionNotice(message: message)
                }

                Spacer(minLength: 0)
                walkingRabbit
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.themeColorBlue)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsTutorial = true
                    } label: {
                        Image(.genbausa)
                            .resizable()
                            .scaledToFit()
                    }
                    .accessibilityLabel("あそびかた")
                }
            }
            .sheet(isPresented: $showsTutorial) {
                TutorialView()
            }
        }
        .onAppear {
            isVisible = true
        }
        .onDisappear {
            isVisible = false
        }
        .onChange(of: shouldScan, initial: true) { _, scan in
            // ほかのタブにいる間とバックグラウンドでは探さない。さがすタブに戻ってきたら探し直す
            if scan {
                detector.start()
            } else {
                detector.stop()
            }
        }
        .tabItem {
            Image(systemName: "magnifyingglass")
            Text("さがす")
        }
    }

    /// 道の上を歩くうさぎ。元アプリと同じく、うさぎを道の上のほうに重ねる
    private var walkingRabbit: some View {
        Image(.road)
            .resizable()
            .scaledToFit()
            .overlay {
                AnimatedGIFView(assetName: "tekuusa")
                    .padding(.horizontal, 32)
                    .visualEffect { content, proxy in
                        content.offset(y: -proxy.size.height * 0.34)
                    }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("道を歩くうさぎ")
    }
}

/// 位置情報の許可が無いときの案内。設定アプリを開くボタンを出す
struct LocationPermissionNotice: View {
    /// 案内の文言
    let message: String

    @Environment(\.openURL) private var openURL

    /// 許可の状態に合わせた案内の文言。探せる・まだ尋ねていないときは `nil`（案内を出さない）
    static func message(for permission: LocationPermission) -> String? {
        switch permission {
        case .notDetermined, .authorized:
            nil
        case .denied, .restricted:
            "ピースをさがすには、位置情報の利用を許可してね"
        case .reducedAccuracy:
            "ピースをさがすには、「正確な位置情報」をオンにしてね"
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.demomoni(size: 18, relativeTo: .body))
                .multilineTextAlignment(.center)
            Button("設定をひらく") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .font(.demomoni(size: 18, relativeTo: .body))
            .buttonStyle(.glassProminent)
            .tint(.themeColorPink)
            .foregroundStyle(Color.themeColorGray)
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
}
