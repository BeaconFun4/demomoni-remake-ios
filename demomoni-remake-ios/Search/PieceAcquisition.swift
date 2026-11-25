//
//  PieceAcquisition.swift
//  demomoni-remake-ios
//

import Foundation

/// 範囲に入ったピースを「ゲットした」画面に出すかの判定
nonisolated enum PieceAcquisition {
    /// 範囲に入ったピース（近い順）のうち、まだ獲得していないいちばん近いもの。すべて獲得済みなら `nil`（もう一度「ゲットした」画面を出さない）。
    /// 範囲が重なる場所では 1 つずつゲットする（ゲット画面を閉じると調べ直し、次のピースが出る）
    static func newPiece(detected: [Piece], collectedPieceIDs: Set<Int>) -> Piece? {
        detected.first { !collectedPieceIDs.contains($0.id) }
    }
}

/// 「ゲットした」画面に出すピースと、獲得した日時
struct GotPiece: Identifiable, Hashable {
    let piece: Piece
    let collectedAt: Date

    var id: Int {
        piece.id
    }
}
