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
    /// ピースの裏側に入れた、その場所で撮った写真（JPEG。長い辺を縮め、位置情報などのメタデータを消したもの。`PiecePhotoImage`）。
    /// まだ入れていなければ `nil`。大きいので、ストアの外のファイルに置く。
    /// 前の版のストアには無い値なので任意にする（軽量の移行で、前の版の記録は `nil` のまま開ける）
    @Attribute(.externalStorage)
    var photo: Data?
    /// 写真の上に手書きした `PKDrawing` のデータ。写真を正方形に切り抜いた枠を 400 × 400 とした座標（`SignatureDrawing`）。
    /// 書いていなければ `nil`
    @Attribute(.externalStorage)
    var photoDrawing: Data?

    init(pieceID: Int, collectedAt: Date, signature: Data? = nil, photo: Data? = nil, photoDrawing: Data? = nil) {
        self.pieceID = pieceID
        self.collectedAt = collectedAt
        self.signature = signature
        self.photo = photo
        self.photoDrawing = photoDrawing
    }
}
