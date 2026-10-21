//
//  RiddleProgress.swift
//  demomoni-remake-ios
//

import Foundation

/// なぞなぞを解いたか（答えの場所のピースを獲得したか）の判定
nonisolated enum RiddleProgress {
    /// 一覧の印の読み上げ（VoiceOver の値）
    static let solvedAccessibilityValue = "ゲットずみ"

    /// なぞなぞの答えの場所のピースを獲得していれば、解いたことにする（答えを出す）
    static func isSolved(_ riddle: Riddle, collectedPieceIDs: Set<Int>) -> Bool {
        collectedPieceIDs.contains(riddle.pieceId)
    }

    /// 詳細に出す答えの文言（例: こたえ：五稜郭タワー）
    static func answerText(for riddle: Riddle) -> String {
        "こたえ：\(riddle.answer)"
    }

    /// 答えの読み上げ（例: こたえ、五稜郭タワー）
    static func answerAccessibilityLabel(for riddle: Riddle) -> String {
        "こたえ、\(riddle.answer)"
    }
}
