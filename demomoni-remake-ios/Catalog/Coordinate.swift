//
//  Coordinate.swift
//  demomoni-remake-ios
//

import CoreLocation
import Foundation

/// 緯度・経度（度）。`CLLocationCoordinate2D` は `Equatable` でないので、判定とテストではこの値を使う
nonisolated struct Coordinate: Hashable, Sendable {
    let latitude: Double
    let longitude: Double

    /// 2 点の間の距離（メートル）。CoreLocation と同じ計算（`CLLocation.distance(from:)`）
    func distance(to other: Self) -> Double {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }
}
