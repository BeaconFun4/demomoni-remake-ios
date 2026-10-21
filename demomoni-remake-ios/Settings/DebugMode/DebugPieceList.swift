//
//  DebugPieceList.swift
//  demomoni-remake-ios
//

#if DEBUG
import Foundation

/// デバッグモードのピースの一覧の並べ方（Debug 構成だけ）
nonisolated enum DebugPieceList {
    /// 一覧の 1 行。ピースと、獲得済みか
    struct Row: Equatable, Identifiable, Sendable {
        let piece: Piece
        let isCollected: Bool

        var id: Int { piece.id }

        /// 行の名前（例: No.14 元町公園）。番号の無いピースは名前だけ
        var title: String {
            piece.number.map { "No.\($0) \(piece.name)" } ?? piece.name
        }
    }

    /// ピースを盤の番号の順（番号の無いものは最後に id の順）に並べ、獲得済みかを添える
    static func rows(pieces: [Piece], collectedPieceIDs: Set<Int>) -> [Row] {
        pieces
            .sorted { ($0.number ?? .max, $0.id) < ($1.number ?? .max, $1.id) }
            .map { Row(piece: $0, isCollected: collectedPieceIDs.contains($0.id)) }
    }
}
#endif
