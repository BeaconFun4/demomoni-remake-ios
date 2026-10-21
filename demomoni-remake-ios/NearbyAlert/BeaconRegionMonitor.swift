//
//  BeaconRegionMonitor.swift
//  demomoni-remake-ios
//

import CoreLocation
import Foundation

/// ビーコンの範囲に入った・出たを見張る仕組み。実機では `CLMonitor`（`CoreLocationBeaconRegionMonitor`）、
/// UI テストと Unit テストのホストでは何もしないもの（`InactiveBeaconRegionMonitor`）に差し替える
protocol BeaconRegionMonitor: AnyObject {
    /// 範囲に入った・出た出来事。受け取るのは 1 か所だけ（`NearbyPieceAlerts`）
    var events: AsyncStream<BeaconRegionEvent> { get }
    /// 位置情報が「常に」で、正確な位置情報もオンか（アプリを閉じている間も出来事が届く）
    var isAlwaysAuthorizedWithFullAccuracy: Bool { get }
    /// 位置情報（常に）の session を始める。持っている間だけ、アプリを閉じていても出来事が届く
    func makeAlwaysSession() -> any LocationSession
    /// 見張る条件をこの一覧にそろえる（無いものは足し、一覧に無いものは外す）
    func setConditions(_ conditions: [MonitoredBeacon]) async
    /// 見張る条件をすべて外す。条件はアプリを終えても残るので、オフにしたとき・オフのまま起動したときに呼ぶ
    func removeAllConditions() async
}

/// `CLMonitor` の `BeaconIdentityCondition` でビーコンの範囲を見張る
final class CoreLocationBeaconRegionMonitor: BeaconRegionMonitor {
    let events: AsyncStream<BeaconRegionEvent>

    nonisolated private let continuation: AsyncStream<BeaconRegionEvent>.Continuation
    /// 許可の状態を読むためだけに持つ
    private let manager = CLLocationManager()
    /// 最初に条件を扱うときに開く（オンにしたことの無い人には作らない）
    private var monitor: CLMonitor?
    /// `monitor.events` を受け続ける処理
    private var eventTask: Task<Void, Never>?

    init() {
        (events, continuation) = AsyncStream.makeStream(of: BeaconRegionEvent.self)
    }

    isolated deinit {
        eventTask?.cancel()
        continuation.finish()
    }

    var isAlwaysAuthorizedWithFullAccuracy: Bool {
        manager.authorizationStatus == .authorizedAlways && manager.accuracyAuthorization == .fullAccuracy
    }

    func makeAlwaysSession() -> any LocationSession {
        CLServiceSession(authorization: .always)
    }

    func setConditions(_ conditions: [MonitoredBeacon]) async {
        let monitor = await openMonitor()
        let wanted = Set(conditions.map(\.identifier))
        for identifier in await monitor.identifiers where !wanted.contains(identifier) {
            await monitor.remove(identifier)
        }
        let existing = Set(await monitor.identifiers)
        for condition in conditions where !existing.contains(condition.identifier) {
            await monitor.add(condition.beaconIdentityCondition, identifier: condition.identifier)
        }
    }

    func removeAllConditions() async {
        let monitor = await openMonitor()
        for identifier in await monitor.identifiers {
            await monitor.remove(identifier)
        }
    }

    /// 同じ名前の `CLMonitor` を開き、出来事を受け始める（前に足した条件と、起動の理由になった出来事も届く）
    private func openMonitor() async -> CLMonitor {
        if let monitor {
            return monitor
        }
        let opened = await CLMonitor(NearbyPieceMonitoring.monitorName)
        // 開くのを待っている間に、別の呼び出しが先に開いていたらそちらを使う
        if let monitor {
            return monitor
        }
        monitor = opened
        let openedEvents = await opened.events
        let continuation = continuation
        eventTask = Task {
            do {
                for try await event in openedEvents {
                    continuation.yield(BeaconRegionEvent(event))
                }
            } catch {
                // 出来事が届かなくなっても、通知が出ないだけなので何もしない
            }
        }
        return opened
    }
}

extension MonitoredBeacon {
    /// `CLMonitor` に足す条件
    nonisolated var beaconIdentityCondition: CLMonitor.BeaconIdentityCondition {
        if let major, let minor {
            return CLMonitor.BeaconIdentityCondition(uuid: uuid, major: major, minor: minor)
        }
        if let major {
            return CLMonitor.BeaconIdentityCondition(uuid: uuid, major: major)
        }
        return CLMonitor.BeaconIdentityCondition(uuid: uuid)
    }
}

extension BeaconRegionEvent {
    /// `CLMonitor` の出来事から作る。`refinement` が major・minor まで分かるビーコンなら、そのビーコンを入れる
    nonisolated init(_ event: CLMonitor.Event) {
        let refinement = event.refinement as? CLMonitor.BeaconIdentityCondition
        let beacon = refinement.flatMap { condition -> DetectedBeacon? in
            guard let major = condition.major, let minor = condition.minor else {
                return nil
            }
            return DetectedBeacon(uuid: condition.uuid, major: major, minor: minor)
        }
        self.init(identifier: event.identifier, isInside: event.state == .satisfied, beacon: beacon)
    }
}

/// 何もしない見張り。UI テストと Unit テストのホストで、`CLMonitor`・`CLServiceSession` を作らないために使う
final class InactiveBeaconRegionMonitor: BeaconRegionMonitor {
    let events = AsyncStream<BeaconRegionEvent> { $0.finish() }
    let isAlwaysAuthorizedWithFullAccuracy = false

    func makeAlwaysSession() -> any LocationSession {
        FakeLocationSession()
    }

    func setConditions(_ conditions: [MonitoredBeacon]) async {}

    func removeAllConditions() async {}
}
