//
//  CoreLocationScanner.swift
//  demomoni-remake-ios
//

import CoreLocation
import Foundation

/// `CLLocationManager` の位置の更新（`startUpdatingLocation()`）で今いる場所を測る。
/// デリゲートは出来事を `events` に流すだけにし、どのスレッドで呼ばれても受け取る側（MainActor）で扱えるようにする
final class CoreLocationScanner: NSObject, LocationScanner {
    let events: AsyncStream<LocationScanEvent>
    /// `events` に出来事を流す。Sendable なので、`nonisolated` のデリゲートから呼べる
    nonisolated private let continuation: AsyncStream<LocationScanEvent>.Continuation

    private let manager = CLLocationManager()

    override init() {
        (events, continuation) = AsyncStream.makeStream(of: LocationScanEvent.self)
        super.init()
        manager.delegate = self
        // 名所の前まで歩いて来たかを 100 m の範囲で判定するので、いちばん高い精度で測る。
        // 動いた距離で間引かない（使い始めた直後の古い位置を捨てた後、止まっていても新しい位置で判定するため）
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
    }

    deinit {
        continuation.finish()
    }

    var permission: LocationPermission {
        LocationPermission(manager.authorizationStatus, accuracy: manager.accuracyAuthorization)
    }

    func makeSession() -> any LocationSession {
        // 正確な位置情報は求めない（fullAccuracyPurposeKey を渡さない）。オフのときは今までどおり画面で案内する
        CLServiceSession(authorization: .whenInUse)
    }

    func startUpdating() {
        manager.startUpdatingLocation()
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
    }
}

extension CoreLocationScanner: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // 「正確な位置情報」を切り替えたときも、このメソッドが呼ばれる
        let permission = LocationPermission(manager.authorizationStatus, accuracy: manager.accuracyAuthorization)
        continuation.yield(.permissionChanged(permission))
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // 古い順に届くので、いちばん新しい位置だけで判定する
        guard let location = locations.last else {
            return
        }
        continuation.yield(.located(LocationFix(location)))
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        // 位置がまだ分からない（kCLErrorLocationUnknown）ときは CoreLocation が測り続けるので、何もしない。
        // 許可を取り消されたときは locationManagerDidChangeAuthorization(_:) で扱う
    }
}

extension CLServiceSession: LocationSession {}
