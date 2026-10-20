//
//  SearchViewTests.swift
//  demomoni-remake-iosTests
//

@testable import demomoni_remake_ios
import SwiftUI
import Testing

struct SearchViewTests {
    /// さがすタブが画面に出ていて、バックグラウンドでないときだけ探す
    @Test(arguments: [
        (true, ScenePhase.active, true),
        (true, .inactive, true),
        (true, .background, false),
        (false, .active, false),
        (false, .inactive, false),
        (false, .background, false)
    ])
    func scansOnlyWhileVisibleInForeground(isVisible: Bool, scenePhase: ScenePhase, expected: Bool) {
        #expect(SearchView.shouldScan(isVisible: isVisible, scenePhase: scenePhase, isCovered: false) == expected)
    }

    /// チュートリアルやゲット画面で覆われている間は探さない
    @Test(arguments: [ScenePhase.active, .inactive, .background])
    func doesNotScanWhileCovered(scenePhase: ScenePhase) {
        #expect(!SearchView.shouldScan(isVisible: true, scenePhase: scenePhase, isCovered: true))
    }
}
