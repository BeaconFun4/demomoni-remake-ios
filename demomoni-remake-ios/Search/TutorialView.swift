//
//  TutorialView.swift
//  demomoni-remake-ios
//

import SwiftUI

/// さがすタブのチュートリアル。なぞなぞタブでなぞなぞを解くとピースの場所が分かることを伝える。
/// 元アプリと同じく、画面のどこを押しても閉じる
struct TutorialView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(.genbausa)
                    .resizable()
                    .scaledToFit()
                    .containerRelativeFrame(.vertical) { height, _ in
                        height * 0.3
                    }
                    .accessibilityHidden(true)
                VStack(spacing: 8) {
                    Text("ここをおしてなぞなぞをとくと")
                    Text("ピースのありかがわかるよ！！")
                }
                .font(.demomoni(size: 24, relativeTo: .title2))
                .multilineTextAlignment(.center)
                .accessibilityElement(children: .combine)
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.themeColorYellow)
            .contentShape(.rect)
            .onTapGesture {
                dismiss()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("とじる", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    TutorialView()
}
