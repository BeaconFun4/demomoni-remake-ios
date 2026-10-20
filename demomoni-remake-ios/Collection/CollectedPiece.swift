//
//  CollectedPiece.swift
//  demomoni-remake-ios
//

import Foundation
import SwiftData

/// 獲得したピースの記録。1 ピースにつき 1 件だけ保存する
@Model
final class CollectedPiece {
    /// 獲得したピースの `Piece.id`
    @Attribute(.unique)
    var pieceID: Int
    /// 最初に獲得した日時
    var collectedAt: Date
    /// サインの `PKDrawing` のデータ（`PKDrawing.dataRepresentation()`）。まだ書いていなければ `nil`。
    /// 大きくなることがあるので、ストアの外のファイルに置く（一覧で id だけを読むときに読み込まない）
    @Attribute(.externalStorage)
    var signature: Data?

    init(pieceID: Int, collectedAt: Date, signature: Data? = nil) {
        self.pieceID = pieceID
        self.collectedAt = collectedAt
        self.signature = signature
    }
}
