//
//  Riddle.swift
//  demomoni-remake-ios
//

import Foundation

/// なぞなぞの 1 問（`riddles.json` の 1 件）。ピースと 1 対 1 で、答えはそのピースの場所の名前
nonisolated struct Riddle: Decodable, Hashable, Identifiable, Sendable {
    /// なぞなぞの id
    let id: Int
    /// 答えの場所にあるピースの `Piece.id`（なぞなぞを解く → その場所へ行く → ピースを獲得する）
    let pieceId: Int
    /// 一覧に出すタイトル（例: 函館ののっぽ）
    let title: String
    /// 問題文
    let content: String
    /// 「ヒントをみる」で出すヒント。答えの 1 文字を「◯」で伏せたもの（例: 函◯山）
    let hint: String
    /// 答え（ピースの場所の名前。例: 函館山）
    let answer: String
    /// なぞなぞの答えがあるエリア（例: goryokaku）
    let area: String
}
