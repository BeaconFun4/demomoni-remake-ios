//
//  Beacon.swift
//  demomoni-remake-ios
//

import Foundation

/// 街に置いた iBeacon の 1 台（`beacons.json` の 1 件）。
/// `beaconId` が同じ値の `Piece.id` のピースに対応する
nonisolated struct Beacon: Decodable, Hashable, Sendable {
    /// 対応するピースの `Piece.id`
    let beaconId: Int
    /// iBeacon の Proximity UUID
    let uuid: UUID
    /// iBeacon の major
    let major: UInt16
    /// iBeacon の minor
    let minor: UInt16

    /// iBeacon の UUID・major・minor がこのビーコンのものか
    func matches(uuid: UUID, major: UInt16, minor: UInt16) -> Bool {
        self.uuid == uuid && self.major == major && self.minor == minor
    }
}
