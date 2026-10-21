//
//  RiddleDetailView.swift
//  demomoni-remake-ios
//

import SwiftUI

/// なぞなぞの詳細。問題文を出し、「ヒントをみる」でヒントを出す。
/// 元のデータに答えが無いので、答え合わせはしない
struct RiddleDetailView: View {
    let riddle: Riddle

    /// ヒントを出したか。詳細を開き直すと隠れた状態に戻る
    @State private var showsHint = false

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Text(riddle.content)
                    .font(.demomoni(size: 26, relativeTo: .title2))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .glassEffect(.regular, in: .rect(cornerRadius: 24))

                if showsHint {
                    Text("ヒント：\(riddle.hint)")
                        .font(.demomoni(size: 24, relativeTo: .title3))
                        .multilineTextAlignment(.center)
                        .accessibilityLabel("ヒント、\(riddle.hint)")
                        .transition(.opacity)
                } else {
                    Button("ヒントをみる") {
                        withAnimation {
                            showsHint = true
                        }
                    }
                    .font(.demomoni(size: 22, relativeTo: .title3))
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .tint(.themeColorPink)
                    // 白い文字ではピンクとのコントラストが足りない（約 2.4:1）ので、元アプリのグレーにする（約 3.6:1）
                    .foregroundStyle(Color.themeColorGray)
                }
            }
            .padding()
        }
        .background(Color.themeColorBlue)
        .navigationTitle(riddle.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        RiddleDetailView(riddle: Catalog.bundled.riddles[0])
    }
}
