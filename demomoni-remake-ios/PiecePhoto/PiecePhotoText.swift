//
//  PiecePhotoText.swift
//  demomoni-remake-ios
//

import Foundation

/// ピースの裏側の写真の文言
nonisolated enum PiecePhotoText {
    /// 写真が無いときに裏側に出す案内
    static let placeholder = "その場所でとった\nしゃしんをいれよう！"

    /// 裏側の読み上げ。写真があるか・その上に手書きしたかで変える
    static func backLabel(hasPhoto: Bool, hasDrawing: Bool) -> String {
        switch (hasPhoto, hasDrawing) {
        case (false, _):
            "ピースのうら、しゃしんはまだないよ"
        case (true, false):
            "ピースのうらのしゃしん"
        case (true, true):
            "かきこんだピースのうらのしゃしん"
        }
    }
}
