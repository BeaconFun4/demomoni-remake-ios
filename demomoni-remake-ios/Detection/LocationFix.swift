//
//  LocationFix.swift
//  demomoni-remake-ios
//

import CoreLocation
import Foundation

/// 測った位置の 1 つ。`CLLocation` から、ピースの場所の範囲の判定（`PieceArea`）に要る値だけを写したもの
nonisolated struct LocationFix: Hashable, Sendable {
    let coordinate: Coordinate
    /// 水平の精度（メートル）。負の値なら位置は無効
    let horizontalAccuracy: Double
    /// 測った日時
    let timestamp: Date
}

extension LocationFix {
    /// CoreLocation の位置から作る
    nonisolated init(_ location: CLLocation) {
        self.init(
            coordinate: Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude),
            horizontalAccuracy: location.horizontalAccuracy,
            timestamp: location.timestamp
        )
    }
}
