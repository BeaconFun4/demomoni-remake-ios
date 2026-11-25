//
//  PieceArea.swift
//  demomoni-remake-ios
//

import Foundation

/// ピースの場所の範囲（ピースの緯度・経度を中心にした半径 `radius` の円）の判定。
/// 範囲に入ったら、そのピースをゲットできる。CoreLocation の出来事から切り出してテストする
nonisolated enum PieceArea {
    /// 範囲の半径（メートル）
    static let radius: Double = 100
    /// 判定に使う位置の精度の下限（メートル）。`horizontalAccuracy` がこれより大きい位置（基地局などから測った粗い位置）は使わない。
    /// 粗い位置で、範囲の外からゲットしないようにする
    static let maximumHorizontalAccuracy: Double = 100
    /// 判定に使う位置の古さの上限（秒）。位置情報を使い始めた直後は、前に測った古い位置が届くことがあるため
    static let maximumAge: TimeInterval = 30

    /// 判定に使える位置か。無効な位置・精度の悪い位置・古い位置は使わない
    static func isUsable(_ fix: LocationFix, now: Date) -> Bool {
        fix.horizontalAccuracy >= 0
            && fix.horizontalAccuracy <= maximumHorizontalAccuracy
            && now.timeIntervalSince(fix.timestamp) <= maximumAge
    }

    /// 位置が範囲に入っているピースを、近い順に並べる（獲得済みかは見ない）。判定に使えない位置なら空
    static func pieces(around fix: LocationFix, in pieces: [Piece], now: Date) -> [Piece] {
        guard isUsable(fix, now: now) else {
            return []
        }
        return pieces
            .map { (piece: $0, distance: fix.coordinate.distance(to: $0.coordinate)) }
            .filter { $0.distance <= radius }
            // 同じ距離なら同梱データの順（sorted は安定）
            .sorted { $0.distance < $1.distance }
            .map(\.piece)
    }
}
