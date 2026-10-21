//
//  Riddle.swift
//  demomoni-remake-ios
//

import Foundation

/// なぞなぞの 1 問（`riddles.json` の 1 件）。答えは元のデータに無いので持たない
nonisolated struct Riddle: Decodable, Hashable, Identifiable, Sendable {
    /// なぞなぞの id
    let id: Int
    /// 一覧に出すタイトル（例: 函館ののっぽ）
    let title: String
    /// 問題文
    let content: String
    /// 「ヒントをみる」で出すヒント
    let hint: String
    /// なぞなぞの答えがあるエリア（例: goryokaku）
    let area: String
}
