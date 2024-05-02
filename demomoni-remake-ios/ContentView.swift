//
//  ContentView.swift
//  demomoni-remake-ios
//
//  Created by 村石 拓海 on 2024/05/02.
//

import SwiftUI

struct ContentView: View {
    @State var selection = 2
    
    var body: some View {
        TabView(selection: $selection) {
            RiddleView()
                .tag(1)
            
            SearchView()
                .tag(2)
            
            PieceListView()
                .tag(3)
        }
    }
}

#Preview {
    ContentView()
}
