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
            RiddleView()
            
            SearchView()
            
            Text("いちらん画面")
                .tabItem {
                    Image(systemName: "puzzlepiece.extension")
                    Text("いちらん")
                }
        }
    }
}

#Preview {
    ContentView()
}
