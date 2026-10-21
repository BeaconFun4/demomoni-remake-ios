//
//  RiddleView.swift
//  demomoni-remake-ios
//
//  Created by 村石 拓海 on 2024/05/02.
//

import SwiftData
import SwiftUI

/// なぞなぞタブ。なぞなぞのタイトルを並べ、押すと詳細を開く。
/// 答えの場所のピースを獲得したなぞなぞには印を付ける
struct RiddleView: View {
    @Environment(\.catalog) private var catalog
    @Query private var collected: [CollectedPiece]

    var body: some View {
        let collectedPieceIDs = Set(collected.map(\.pieceID))
        NavigationStack {
            List(catalog.riddles) { riddle in
                let isSolved = RiddleProgress.isSolved(riddle, collectedPieceIDs: collectedPieceIDs)
                NavigationLink(value: riddle) {
                    HStack {
                        Text(riddle.title)
                            .font(.demomoni(size: 20))
                            .padding(.vertical, 8)
                        Spacer()
                        if isSolved {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title2)
                                .foregroundStyle(Color.themeColorPink)
                        }
                    }
                }
                // 読み上げと UI テストはタイトルで探せるようにし、印は値として読む
                .accessibilityLabel(riddle.title)
                .accessibilityValue(isSolved ? RiddleProgress.solvedAccessibilityValue : "")
            }
            .scrollContentBackground(.hidden)
            .background(Color.themeColorBlue)
            .navigationTitle("なぞなぞ")
            .navigationDestination(for: Riddle.self) { riddle in
                RiddleDetailView(riddle: riddle)
            }
        }
        .tabItem {
            Image(systemName: "questionmark.bubble.fill")
            Text("なぞなぞ")
        }
    }
}

#Preview {
    TabView {
        RiddleView()
    }
    // swiftlint:disable:next force_try
    .modelContainer(try! .demomoni(inMemory: true))
}
