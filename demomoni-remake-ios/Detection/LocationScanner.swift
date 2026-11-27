//
//  LocationScanner.swift
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
    /// 使用中の許可はあるが「正確な位置情報」がオフ。位置が数 km ずれるので、ピースの場所の範囲（`PieceArea`）を判定できない
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

/// `LocationScanner` から届く出来事
nonisolated enum LocationScanEvent: Equatable, Sendable {
    /// 位置情報の許可が変わった
    case permissionChanged(LocationPermission)
    /// 今いる場所を測った
    case located(LocationFix)
}

/// 位置情報を使う間だけ持つ session（実機では `CLServiceSession`）。使い終えたら `invalidate()` する
protocol LocationSession: AnyObject {
    /// session を終える
    func invalidate()
}

/// 今いる場所を調べる仕組み。実機では CoreLocation（`CoreLocationScanner`）、
/// UI テストと PR の撮影では擬似検知（`FakeLocationScanner`）に差し替える
protocol LocationScanner: AnyObject {
    /// 今の位置情報の許可
    var permission: LocationPermission { get }
    /// 許可の変化と測った位置。受け取るのは 1 か所だけ（`PieceDetector`）
    var events: AsyncStream<LocationScanEvent> { get }
    /// 位置情報（使用中）の session を始める。まだ許可を尋ねていなければ、始めたときに尋ねる
    func makeSession() -> any LocationSession
    /// 今いる場所を測り始める
    func startUpdating()
    /// 測るのをやめる
    func stopUpdating()
}
