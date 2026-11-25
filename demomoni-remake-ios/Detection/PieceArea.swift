//
//  PieceArea.swift
//  demomoni-remake-ios
//

import Foundation

/// ピースの場所の範囲（ピースの緯度・経度を中心にした半径 `Piece.radius` の円）の判定。
/// 範囲に入ったら、そのピースをゲットできる。CoreLocation の出来事から切り出してテストする
nonisolated enum PieceArea {
    /// 判定に使う位置の精度の上限（メートル）の最小値。建物の中で Wi-Fi から測った位置（数十〜100 m ほど）でもゲットできるようにし、
    /// 基地局だけから測った粗い位置（数百 m〜数 km）は使わない
    static let minimumAccuracyLimit: Double = 150
    /// 判定に使う位置の古さの上限（秒）。位置情報を使い始めた直後は、前に測った古い位置が届くことがあるため
    static let maximumAge: TimeInterval = 30

    /// 半径 `radius` の範囲の判定に使う位置の精度の上限（メートル）。
    /// 150 m と範囲の半径の大きいほう（広い場所は、範囲と同じくらいの粗さの位置でも判定できる）
    static func accuracyLimit(forRadius radius: Double) -> Double {
        max(minimumAccuracyLimit, radius)
    }

    /// 判定に使える新しさの位置か。無効な位置（精度が負）・古い位置は使わない
    static func isRecent(_ fix: LocationFix, now: Date) -> Bool {
        fix.horizontalAccuracy >= 0 && now.timeIntervalSince(fix.timestamp) <= maximumAge
    }

    /// 位置がピースの範囲に入っているか。精度がその範囲の上限（`accuracyLimit(forRadius:)`）より悪い位置では入っていないことにする。
    /// 位置の新しさは見ない（`isRecent(_:now:)`）
    static func contains(_ fix: LocationFix, in piece: Piece) -> Bool {
        fix.horizontalAccuracy <= accuracyLimit(forRadius: piece.radius)
            && fix.coordinate.distance(to: piece.coordinate) <= piece.radius
    }

    /// 位置が範囲に入っているピースを、中心が近い順に並べる（獲得済みかは見ない）。判定に使えない位置なら空
    static func pieces(around fix: LocationFix, in pieces: [Piece], now: Date) -> [Piece] {
        guard isRecent(fix, now: now) else {
            return []
        }
        return pieces
            .filter { contains(fix, in: $0) }
            .map { (piece: $0, distance: fix.coordinate.distance(to: $0.coordinate)) }
            // 同じ距離なら同梱データの順（sorted は安定）
            .sorted { $0.distance < $1.distance }
            .map(\.piece)
    }
}
