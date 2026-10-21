//
//  CoreLocationBeaconScanner.swift
//  demomoni-remake-ios
//

import CoreLocation
import Foundation

/// `CLLocationManager` の ranging（`CLBeaconIdentityConstraint`）で iBeacon を探す。
/// デリゲートは出来事を `events` に流すだけにし、どのスレッドで呼ばれても受け取る側（MainActor）で扱えるようにする
final class CoreLocationBeaconScanner: NSObject, BeaconScanner {
    let events: AsyncStream<BeaconScanEvent>
    /// `events` に出来事を流す。Sendable なので、`nonisolated` のデリゲートから呼べる
    nonisolated private let continuation: AsyncStream<BeaconScanEvent>.Continuation

    private let manager = CLLocationManager()
    /// ranging している制約
    private var constraints: [CLBeaconIdentityConstraint] = []

    override init() {
        (events, continuation) = AsyncStream.makeStream(of: BeaconScanEvent.self)
        super.init()
        manager.delegate = self
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

    func startRanging(uuids: Set<UUID>) {
        stopRanging()
        // Simulator など ranging できない端末では何もしない
        guard CLLocationManager.isRangingAvailable() else {
            return
        }
        constraints = uuids.map { CLBeaconIdentityConstraint(uuid: $0) }
        for constraint in constraints {
            manager.startRangingBeacons(satisfying: constraint)
        }
    }

    func stopRanging() {
        for constraint in constraints {
            manager.stopRangingBeacons(satisfying: constraint)
        }
        constraints = []
    }
}

extension CoreLocationBeaconScanner: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // 「正確な位置情報」を切り替えたときも、このメソッドが呼ばれる
        let permission = LocationPermission(manager.authorizationStatus, accuracy: manager.accuracyAuthorization)
        continuation.yield(.permissionChanged(permission))
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didRange beacons: [CLBeacon],
        satisfying beaconConstraint: CLBeaconIdentityConstraint
    ) {
        // 元アプリと同じく、距離（proximity）は見ずに UUID・major・minor で判定する
        let detected = beacons.map {
            DetectedBeacon(uuid: $0.uuid, major: $0.major.uint16Value, minor: $0.minor.uint16Value)
        }
        continuation.yield(.ranged(detected))
    }
}

extension CLServiceSession: LocationSession {}
