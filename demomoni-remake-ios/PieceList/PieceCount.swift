//
//  PieceCount.swift
//  demomoni-remake-ios
//

import Foundation

/// いちらんの盤の上に出す、ゲットしたピースの数と同梱の全ピースの数
nonisolated struct PieceCount: Equatable, Sendable {
    /// ゲットしたピースの数（同梱にある id だけを、重なりを除いて数える）
    let collected: Int
    /// 同梱の全ピースの数
    let total: Int

    /// 同梱のピースと、獲得したピースの id（記録の順。重なっていてもよい）から数える
    init(pieces: [Piece], collectedPieceIDs: some Sequence<Int>) {
        let bundledIDs = Set(pieces.map(\.id))
        collected = Set(collectedPieceIDs).intersection(bundledIDs).count
        total = pieces.count
    }

    /// 盤の上に出す文字（例: 3 / 32）
    var text: String {
        "\(collected) / \(total)"
    }

    /// 数の読み上げ（例: ゲットしたピース 3 こ、全部で 32 こ）
    var accessibilityLabel: String {
        "ゲットしたピース \(collected) こ、全部で \(total) こ"
    }
}
