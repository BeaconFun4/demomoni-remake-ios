//
//  BeaconScanner.swift
//  demomoni-remake-ios
//

import CoreLocation
import Foundation

/// 位置情報（使用中）の許可の状態
nonisolated enum LocationPermission: Equatable, Sendable {
    /// まだ尋ねていない
    case notDetermined
    /// 利用者が許可しなかった（設定アプリで変えられる）
    case denied
    /// 機能制限などで許可できない
    case restricted
    /// 使用中の許可はあるが「正確な位置情報」がオフ。iBeacon の ranging はできない
    case reducedAccuracy
    /// 使用中の許可があり、正確な位置情報も使える
    case authorized

    /// CoreLocation の許可と精度から作る
    init(_ status: CLAuthorizationStatus, accuracy: CLAccuracyAuthorization = .fullAccuracy) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .restricted:
            self = .restricted
        case .authorizedWhenInUse, .authorizedAlways:
            self = accuracy == .fullAccuracy ? .authorized : .reducedAccuracy
        case .denied:
            self = .denied
        @unknown default:
            self = .denied
        }
    }
}

/// 見つけた iBeacon の識別子
nonisolated struct DetectedBeacon: Hashable, Sendable {
    let uuid: UUID
    let major: UInt16
    let minor: UInt16
}

extension DetectedBeacon {
    /// 同梱データのビーコンを見つけたことにする（擬似検知用）
    nonisolated init(_ beacon: Beacon) {
        self.init(uuid: beacon.uuid, major: beacon.major, minor: beacon.minor)
    }
}

/// `BeaconScanner` から届く出来事
nonisolated enum BeaconScanEvent: Equatable, Sendable {
    /// 位置情報の許可が変わった
    case permissionChanged(LocationPermission)
    /// ranging で近くの iBeacon が見つかった（空のこともある）
    case ranged([DetectedBeacon])
}

/// iBeacon を探す仕組み。実機では CoreLocation（`CoreLocationBeaconScanner`）、
/// UI テストと PR の撮影では擬似検知（`FakeBeaconScanner`）に差し替える
protocol BeaconScanner: AnyObject {
    /// 今の位置情報の許可
    var permission: LocationPermission { get }
    /// 許可の変化と見つけたビーコンを受け取る
    var onEvent: (@MainActor (BeaconScanEvent) -> Void)? { get set }
    /// 位置情報（使用中）の許可を尋ねる
    func requestPermission()
    /// UUID ごとに iBeacon の ranging を始める
    func startRanging(uuids: Set<UUID>)
    /// ranging をやめる
    func stopRanging()
}
