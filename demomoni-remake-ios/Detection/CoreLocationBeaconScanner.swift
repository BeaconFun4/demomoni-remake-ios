//
//  CoreLocationBeaconScanner.swift
//  demomoni-remake-ios
//

import CoreLocation
import Foundation

/// `CLLocationManager` の ranging（`CLBeaconIdentityConstraint`）で iBeacon を探す。
/// MainActor で作るので、デリゲートはメインスレッドで呼ばれる
final class CoreLocationBeaconScanner: NSObject, BeaconScanner {
    var onEvent: (@MainActor (BeaconScanEvent) -> Void)?

    private let manager = CLLocationManager()
    /// ranging している制約
    private var constraints: [CLBeaconIdentityConstraint] = []

    override init() {
        super.init()
        manager.delegate = self
    }

    var permission: LocationPermission {
        LocationPermission(manager.authorizationStatus)
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
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
        let permission = LocationPermission(manager.authorizationStatus)
        MainActor.assumeIsolated {
            onEvent?(.permissionChanged(permission))
        }
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
        MainActor.assumeIsolated {
            onEvent?(.ranged(detected))
        }
    }
}
