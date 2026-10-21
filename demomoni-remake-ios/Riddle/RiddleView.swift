//
//  RiddleView.swift
//  demomoni-remake-ios
//
//  Created by 村石 拓海 on 2024/05/02.
//

import SwiftUI

/// なぞなぞタブ。なぞなぞのタイトルを並べ、押すと詳細を開く
struct RiddleView: View {
    @Environment(\.catalog) private var catalog

    var body: some View {
        NavigationStack {
            List(catalog.riddles) { riddle in
                NavigationLink(value: riddle) {
                    Text(riddle.title)
                        .font(.demomoni(size: 20))
                        .padding(.vertical, 8)
                }
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
}
