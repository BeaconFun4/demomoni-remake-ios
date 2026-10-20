//
//  AnimatedGIFView.swift
//  demomoni-remake-ios
//

import SwiftUI
import UIKit

/// アセットカタログの GIF（dataset）を繰り返し再生する。
/// 視差効果を減らす（Reduce Motion）が有効なときは、最初のフレームで止める
struct AnimatedGIFView: View {
    /// 読み込んだ GIF。読めなければ何も出さない
    private let animation: GIFAnimation?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 再生を始めた時刻。画面に出るたびに最初のフレームから再生する
    @State private var startDate = Date.now

    /// - Parameter assetName: アセットカタログの dataset の名前（例: tekuusa）
    init(assetName: String) {
        animation = NSDataAsset(name: assetName).flatMap { GIFAnimation(data: $0.data) }
    }

    var body: some View {
        if let animation {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
                let index = reduceMotion ? 0 : animation.frameIndex(at: context.date.timeIntervalSince(startDate))
                Image(decorative: animation.frames[index], scale: 1)
                    .resizable()
                    .scaledToFit()
            }
            .onAppear {
                startDate = .now
            }
        }
    }
}
