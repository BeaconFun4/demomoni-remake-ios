//
//  PieceDetailText.swift
//  demomoni-remake-ios
//

import Foundation

/// ピース詳細の文言（元アプリの「ピース No.14」「にちじ:11/27 21:12」などにならう）
nonisolated enum PieceDetailText {
    /// 見出し。番号が無ければ「ピース」
    static func title(for piece: Piece) -> String {
        piece.number.map { "ピース No.\($0)" } ?? "ピース"
    }

    /// 獲得した日時。獲得の記録が無ければ日時を出さない
    static func date(_ collectedAt: Date?, timeZone: TimeZone = .current) -> String {
        "にちじ:" + (collectedAt.map { PieceDateFormat.detailDate($0, timeZone: timeZone) } ?? "")
    }

    /// エリア
    static func area(for piece: Piece) -> String {
        "エリア:\(piece.area)"
    }

    /// 場所の名前
    static func place(for piece: Piece) -> String {
        "ばしょ:\(piece.name)"
    }
}
