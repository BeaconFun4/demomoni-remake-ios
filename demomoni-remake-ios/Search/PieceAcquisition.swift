//
//  PieceAcquisition.swift
//  demomoni-remake-ios
//

import Foundation

/// 検知したピースを「ゲットした」画面に出すかの判定
nonisolated enum PieceAcquisition {
    /// 検知したピースのうち、まだ獲得していないもの。獲得済みなら `nil`（もう一度「ゲットした」画面を出さない）
    static func newPiece(detected: Piece?, collectedPieceIDs: Set<Int>) -> Piece? {
        guard let detected, !collectedPieceIDs.contains(detected.id) else {
            return nil
        }
        return detected
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
