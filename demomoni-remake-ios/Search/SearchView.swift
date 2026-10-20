//
//  SearchView.swift
//  demomoni-remake-ios
//
//  Created by 村石 拓海 on 2024/05/02.
//

import SwiftData
import SwiftUI

/// さがすタブ。表示している間だけ近くの iBeacon を探し、まだ獲得していないピースを見つけたら
/// 獲得を保存して「ピースをゲットしたよ！！」画面を出す。
/// 歩くうさぎと道を出し、`genbausa` のボタンでチュートリアルを開く
struct SearchView: View {
    @Environment(BeaconDetector.self) private var detector
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @State private var showsTutorial = false
    /// 「ゲットした」画面に出しているピース
    @State private var gotPiece: GotPiece?
    /// さがすタブが画面に出ているか。`TabView` はほかのタブにいる間も View を残すので、自分で持つ
    @State private var isVisible = false

    /// 今、探すべきか
    private var shouldScan: Bool {
        Self.shouldScan(
            isVisible: isVisible,
            scenePhase: scenePhase,
            isCovered: showsTutorial || gotPiece != nil
        )
    }

    /// さがすタブが画面に出ていて、アプリがバックグラウンドでなく、
    /// チュートリアルやゲット画面で覆われていないときだけ探す。
    /// 覆われている間に検知すると、獲得を保存したのにゲット画面を出せないことがあるため
    nonisolated static func shouldScan(isVisible: Bool, scenePhase: ScenePhase, isCovered: Bool) -> Bool {
        isVisible && scenePhase != .background && !isCovered
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
            .fullScreenCover(item: $gotPiece) { gotPiece in
                GotPieceView(gotPiece: gotPiece)
            }
        }
        .onChange(of: detector.detectedPiece) { _, detected in
            receive(detected)
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

    /// 検知したピースを受け取る。まだ獲得していなければ獲得を保存し、「ゲットした」画面を出す
    private func receive(_ detected: Piece?) {
        guard detected != nil else {
            return
        }
        detector.clearDetectedPiece()
        let collection = PieceCollection(context: modelContext)
        // チュートリアルやゲット画面を出している間は保存しない（ゲット画面を出せないため。閉じた後の検知でまた拾う）
        guard !showsTutorial,
              gotPiece == nil,
              let collectedPieceIDs = try? collection.collectedPieceIDs(),
              let piece = PieceAcquisition.newPiece(detected: detected, collectedPieceIDs: collectedPieceIDs) else {
            return
        }
        let now = Date.now
        // 保存できなければ「ゲットした」画面も出さない（次に検知したときにもう一度保存する）
        guard (try? collection.collect(pieceID: piece.id, at: now)) == true else {
            return
        }
        gotPiece = GotPiece(piece: piece, collectedAt: now)
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
