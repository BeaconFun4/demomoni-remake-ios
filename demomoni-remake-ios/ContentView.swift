//
//  ContentView.swift
//  demomoni-remake-ios
//
//  Created by 村石 拓海 on 2024/05/02.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Text("なぞなぞ画面")
                .tabItem {
                    Image(systemName: "message.fill")
                    Text("メッセージ")
                }
            Text("さがす画面")
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("さがす")
                }
            Text("いちらん画面")
                .tabItem {
                    Image(systemName: "face.smiling.fill")
                    Text("いちらん")
                }
        }
    }
}

#Preview {
    ContentView()
}
